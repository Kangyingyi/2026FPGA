package cn.codex.fpga_music

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.content.res.ColorStateList
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : AppCompatActivity() {
    companion object { private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") }

    private val adapter: BluetoothAdapter? by lazy { BluetoothAdapter.getDefaultAdapter() }
    private var socket: BluetoothSocket? = null
    private var output: OutputStream? = null
    private val connected = AtomicBoolean(false)
    private val reading = AtomicBoolean(false)
    private var paired = emptyList<BluetoothDevice>()
    private lateinit var deviceSpinner: Spinner
    private lateinit var status: TextView
    private lateinit var stats: TextView
    private lateinit var connectButton: Button
    private lateinit var logView: TextView
    private lateinit var scoreInput: EditText
    private lateinit var scoreDurationInput: EditText
    private lateinit var scoreImagePreview: ImageView
    private val modeButtons = mutableListOf<Button>()
    private val octaveButtons = mutableListOf<Button>()
    private val octaveNames = listOf("低音区", "中音区", "高音区")
    private var selectedOctave = 1
    private var octaveConfirmed = false
    private val modeNames = listOf("默认", "滑音·连奏", "滑音·常开", "颤音", "延时", "拨弦", "回声", "混响", "合唱")
    private var selectedMode = 0
    private var modeConfirmed = false
    private val log = StringBuilder()
    private var mediaPlayer: MediaPlayer? = null
    private val pcmLock = Any()
    private val ackLock = Object()
    private val commandLock = Any()
    private val commandExecutor = Executors.newSingleThreadExecutor()
    private val imageExecutor = Executors.newSingleThreadExecutor()
    @Volatile private var waitingAckFor: Int? = null
    @Volatile private var waitingAckCode: Int? = null
    private val pcm16 = ByteArrayOutputStream()
    @Volatile
    private var recording = false
    private var expectedSequence: Int? = null
    @Volatile private var lastStatsUpdateMs = 0L
    private var missingFrames = 0L
    private var goodFrames = 0L
    private var badFrames = 0L
    @Volatile private var recordingSampleRate = 8000

    private val permissions = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) refreshPairedDevices() else setStatus("需要蓝牙连接权限才能连接 JDY-31")
    }
    private val saveDocument = registerForActivityResult(ActivityResultContracts.CreateDocument("audio/wav")) { uri ->
        if (uri != null) saveWav(uri)
    }
    private val chooseScoreImage = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) recognizeScoreImage(uri)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        buildUi()
        if (adapter == null) setStatus("此手机没有蓝牙功能") else ensurePermissionThenRefresh()
    }

    private fun buildUi() {
        val scroll = ScrollView(this)
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(20, 18, 20, 22); setBackgroundColor(Color.rgb(247,249,252)) }
        scroll.addView(root)
        setContentView(scroll)
        root.addView(text("FPGA 音乐键盘", 26, Color.rgb(20,35,60), true))
        root.addView(text("JDY-31 蓝牙连接 · 音色控制 · 录音回传", 14, Color.DKGRAY))
        root.addView(section("蓝牙连接"))
        deviceSpinner = Spinner(this)
        root.addView(deviceSpinner)
        val connectionRow = row(root)
        connectButton = button("连接 JDY-31") { if (connected.get()) disconnect() else connect() }
        connectionRow.addView(connectButton, weight())
        connectionRow.addView(button("刷新已配对设备") { ensurePermissionThenRefresh() }, weight())
        status = text("未连接。请先在手机蓝牙设置中配对 JDY-31-SPP。", 14, Color.DKGRAY)
        root.addView(status)

        root.addView(section("音色选择"))
        val timbres = listOf("钢琴", "电钢琴", "吉他", "钟琴", "风琴", "长笛", "单簧管", "小提琴")
        timbres.chunked(4).forEachIndexed { rowIndex, group ->
            val line = row(root)
            group.forEachIndexed { col, name ->
                val index = rowIndex * 4 + col
                line.addView(button("${index + 1} $name") { sendCommand(0x10, byteArrayOf(index.toByte())) }, weight())
            }
        }

        root.addView(section("音区选择"))
        val octaveRow = row(root)
        octaveNames.forEachIndexed { octave, label ->
            val octaveButton = button(label) { selectOctave(octave) }
            octaveButtons.add(octaveButton)
            octaveRow.addView(octaveButton, weight())
        }
        updateOctaveButtons()
        root.addView(text("K1～K8 对应哆、瑞、咪、发、梭、拉、西、高哆；默认中音区 C4～C5。", 12, Color.GRAY))

        root.addView(section("演奏模式"))
        modeNames.chunked(3).forEachIndexed { rowIndex, group ->
            val modeRow = row(root)
            group.forEachIndexed { col, name ->
                val mode = rowIndex * 3 + col
                val modeButton = button(name) { selectMode(mode) }
                modeButtons.add(modeButton)
                modeRow.addView(modeButton, weight())
            }
        }
        updateModeButtons()
        root.addView(text("九种模式互斥；延时、回声、混响、合唱为音效模式。收到 FPGA 确认后按钮变蓝。拨弦模式先按住琴键，再遮挡光电传感器。", 12, Color.GRAY))

        root.addView(section("脱机曲目指引"))
        scoreInput = EditText(this).apply {
            hint = "音符列表：0:10,1:10,2:10（音高0-7，时值单位10ms）"
            setSingleLine(false); minLines = 2; setText("0:10,1:10,2:10,0:10")
        }
        root.addView(scoreInput)
        val imageRow = row(root)
        imageRow.addView(button("选择简谱图片") { chooseScoreImage.launch("image/*") }, weight())
        scoreDurationInput = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            setText("50")
            hint = "默认时值/10ms"
            contentDescription = "图片识别默认时值，单位10毫秒"
        }
        imageRow.addView(scoreDurationInput, weight())
        scoreImagePreview = ImageView(this).apply {
            adjustViewBounds = true
            maxHeight = (resources.displayMetrics.density * 240).toInt()
            visibility = View.GONE
        }
        root.addView(scoreImagePreview)
        val scoreRow = row(root)
        scoreRow.addView(button("上传曲谱") { uploadScore(scoreInput.text.toString()) }, weight())
        scoreRow.addView(button("开始指引") { sendCommand(0x23) }, weight())
        scoreRow.addView(button("停止指引") { sendCommand(0x24) }, weight())
        root.addView(text("格式：音高:时值，逗号分隔；0～7 对应当前音区的 K1～K8。上传需逐条等待 FPGA ACK。", 12, Color.GRAY))
        root.addView(text("图片识别仅适用于清晰的数字简谱草稿：数字 1～7 转成 K1～K7。圆点音区、升降号、休止符和真实时值需人工核对；图片缺少时值时统一采用右侧默认值。先检查编辑框，再点上传曲谱。最多 64 音。", 12, Color.GRAY))

        root.addView(section("录音回传"))
        val recRow = row(root)
        recRow.addView(button("开始录音") { beginRecording() }, weight())
        recRow.addView(button("停止录音") { stopRecording() }, weight())
        val playbackRow = row(root)
        playbackRow.addView(button("播放") { playRecording() }, weight())
        playbackRow.addView(button("保存 WAV") { saveDocument.launch("fpga_recording.wav") }, weight())
        stats = text("尚未收到录音帧", 14, Color.DKGRAY)
        root.addView(stats)
        root.addView(text("此版录音为 0x41 原始 PCM、8 kHz 单声道；JDY-31 与 FPGA 串口均为 128000 baud、8-N-1。", 13, Color.rgb(65,90,110)))

        root.addView(section("通信记录"))
        logView = text("", 12, Color.rgb(65,75,90))
        logView.setBackgroundColor(Color.WHITE)
        logView.setPadding(12,12,12,12)
        root.addView(logView)
    }

    private fun section(value: String) = text(value, 18, Color.rgb(30,90,160), true).apply { setPadding(0,22,0,8) }
    private fun text(value: String, size: Int, color: Int, bold: Boolean = false) = TextView(this).apply {
        text = value; textSize = size.toFloat(); setTextColor(color); if (bold) setTypeface(null, android.graphics.Typeface.BOLD)
    }
    private fun row(parent: LinearLayout) = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL; parent.addView(this) }
    private fun weight() = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(3,3,3,3) }
    private fun button(label: String, action: () -> Unit) = Button(this).apply { text = label; isAllCaps = false; setOnClickListener { action() } }

    private fun updateModeButtons() {
        modeButtons.forEachIndexed { index, button ->
            val selected = modeConfirmed && index == selectedMode
            button.backgroundTintList = ColorStateList.valueOf(if (selected) Color.rgb(30, 90, 160) else Color.rgb(220, 225, 230))
            button.setTextColor(if (selected) Color.WHITE else Color.BLACK)
        }
    }

    private fun updateOctaveButtons() {
        octaveButtons.forEachIndexed { index, button ->
            val selected = octaveConfirmed && index == selectedOctave
            button.backgroundTintList = ColorStateList.valueOf(if (selected) Color.rgb(30, 90, 160) else Color.rgb(220, 225, 230))
            button.setTextColor(if (selected) Color.WHITE else Color.BLACK)
        }
    }

    private fun selectOctave(octave: Int) {
        commandExecutor.execute {
            try {
                sendAndWait(0x11, byteArrayOf(octave.toByte()))
                runOnUiThread {
                    selectedOctave = octave
                    octaveConfirmed = true
                    updateOctaveButtons()
                    setStatus("已切换到${octaveNames[octave]}")
                }
            } catch (e: Exception) {
                runOnUiThread { setStatus("切换音区失败：${e.message}") }
            }
        }
    }

    private fun selectMode(mode: Int) {
        commandExecutor.execute {
            try {
                sendAndWait(0x12, byteArrayOf(mode.toByte()))
                runOnUiThread {
                    selectedMode = mode
                    modeConfirmed = true
                    updateModeButtons()
                    setStatus("已切换到${modeNames[mode]}模式")
                }
            } catch (e: Exception) {
                runOnUiThread { setStatus("切换演奏模式失败：${e.message}") }
            }
        }
    }

    private fun hasConnectPermission() = Build.VERSION.SDK_INT < 31 || checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    private fun ensurePermissionThenRefresh() {
        if (!hasConnectPermission()) permissions.launch(Manifest.permission.BLUETOOTH_CONNECT) else refreshPairedDevices()
    }
    @Suppress("MissingPermission")
    private fun refreshPairedDevices() {
        try {
            val devices = adapter?.bondedDevices?.toList().orEmpty()
            paired = devices
            deviceSpinner.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item,
                devices.map { "${it.name ?: "未知设备"}  (${it.address})" }.ifEmpty { listOf("没有已配对设备；先到系统蓝牙设置配对 JDY-31-SPP") })
            setStatus(if (devices.isEmpty()) "尚无已配对设备" else "找到 ${devices.size} 个已配对设备")
        } catch (e: SecurityException) { setStatus("读取已配对设备失败：请授予蓝牙权限") }
    }

    @Suppress("MissingPermission")
    private fun connect() {
        if (!hasConnectPermission()) { ensurePermissionThenRefresh(); return }
        val index = deviceSpinner.selectedItemPosition
        val device = paired.getOrNull(index)
        if (device == null) { setStatus("请先在系统蓝牙设置中配对 JDY-31-SPP"); return }
        connectButton.isEnabled = false
        setStatus("正在连接 ${device.name ?: device.address}…")
        Thread {
            try {
                val newSocket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                newSocket.connect()
                socket = newSocket
                output = newSocket.outputStream
                connected.set(true)
                reading.set(true)
                runOnUiThread { connectButton.text = "断开连接"; connectButton.isEnabled = true; setStatus("蓝牙已连接，正在同步中音区和默认模式") }
                commandExecutor.execute {
                    try {
                        Thread.sleep(400)
                        sendAndWait(0x11, byteArrayOf(1))
                        sendAndWait(0x12, byteArrayOf(0))
                        runOnUiThread {
                            selectedOctave = 1
                            octaveConfirmed = true
                            updateOctaveButtons()
                            selectedMode = 0
                            modeConfirmed = true
                            updateModeButtons()
                            setStatus("已连接：${device.name ?: device.address}；中音区、默认模式")
                        }
                    } catch (e: Exception) {
                        runOnUiThread { setStatus("蓝牙已连接，但 FPGA 同步命令无 ACK：${e.message}") }
                    }
                }
                receiveLoop(newSocket)
            } catch (e: Exception) {
                disconnectInternal()
                runOnUiThread { connectButton.isEnabled = true; connectButton.text = "连接 JDY-31"; setStatus("连接失败：${e.message ?: "请检查配对和模块供电"}") }
            }
        }.start()
    }

    private fun receiveLoop(activeSocket: BluetoothSocket) {
        val parser = FrameParser({ handleFrame(it) }, { badFrames++; updateStats() })
        val chunk = ByteArray(2048)
        try {
            val input = activeSocket.inputStream
            while (reading.get()) {
                val n = input.read(chunk)
                if (n < 0) break
                parser.feed(chunk, n)
            }
        } catch (_: Exception) { }
        disconnectInternal()
        runOnUiThread { connectButton.text = "连接 JDY-31"; connectButton.isEnabled = true; setStatus("蓝牙连接已断开") }
    }

    private fun handleFrame(frame: WireFrame) {
        when (frame.type) {
            0x7F -> {
                if (frame.payload.size >= 2) {
                    val command = frame.payload[0].toInt() and 0xFF
                    val code = frame.payload[1].toInt() and 0xFF
                    synchronized(ackLock) {
                        if (waitingAckFor == command) {
                            waitingAckCode = code
                            ackLock.notifyAll()
                        }
                    }
                    appendLog("ACK 命令 0x%02X：%s".format(command, if (code == 0) "成功" else "错误码 $code"))
                }
            }
            0x41 -> {
                if (frame.payload.size != 66) { badFrames++; updateStats(); return }
                recordingSampleRate = 8000
                val seq = u16(frame.payload, 0)
                val pcm = ShortArray(64) { (frame.payload[it + 2].toInt() shl 8).toShort() }
                appendAudioFrame(seq, pcm)
            }
            0x42 -> {
                val decoded = ImaAdpcm.decode(frame.payload)
                if (decoded == null) { badFrames++; updateStats(); return }
                recordingSampleRate = 12000
                appendAudioFrame(decoded.first, decoded.second)
            }
            else -> appendLog("收到帧 0x%02X，%d 字节".format(frame.type, frame.payload.size))
        }
    }

    private fun u16(bytes: ByteArray, offset: Int) = (bytes[offset].toInt() and 0xFF) or ((bytes[offset + 1].toInt() and 0xFF) shl 8)
    private fun appendAudioFrame(seq: Int, samples: ShortArray) {
        synchronized(pcmLock) {
            if (!recording) return
            val expected = expectedSequence
            if (expected != null) {
                val missing = (seq - expected) and 0xFFFF
                if (missing in 1..1000) {
                    missingFrames += missing
                    repeat(missing * 64) { writeSampleLocked(0) }
                } else if (missing > 1000) {
                    // Treat a large discontinuity (e.g. recorder restarted) as a new segment.
                    expectedSequence = seq
                }
            }
            samples.forEach { writeSampleLocked(it.toInt()) }
            expectedSequence = (seq + 1) and 0xFFFF
            goodFrames++
        }
        updateStats()
    }
    private fun writeSampleLocked(sample: Int) { pcm16.write(sample and 0xFF); pcm16.write((sample ushr 8) and 0xFF) }

    private fun beginRecording() {
        if (!connected.get()) { setStatus("请先连接 JDY-31"); return }
        synchronized(pcmLock) { pcm16.reset(); expectedSequence = null; missingFrames = 0; goodFrames = 0; badFrames = 0; recordingSampleRate = 8000; recording = true }
        commandExecutor.execute {
            try {
                sendAndWait(0x30)
                runOnUiThread { setStatus("FPGA 已确认开始录音，正在接收") }
            } catch (e: Exception) {
                synchronized(pcmLock) { recording = false }
                runOnUiThread { setStatus("开始录音失败：${e.message}") }
            }
        }
        updateStats()
    }
    private fun stopRecording() {
        if (!recording) { setStatus("当前没有录音"); return }
        commandExecutor.execute {
            try {
                sendAndWait(0x31)
                synchronized(pcmLock) { recording = false }
                runOnUiThread { setStatus("FPGA 已确认停止；可试听或保存 WAV") }
                updateStats()
            } catch (e: Exception) { runOnUiThread { setStatus("停止录音未收到确认：${e.message}") } }
        }
    }

    private fun sendCommand(type: Int, payload: ByteArray = byteArrayOf()) {
        commandExecutor.execute {
            try {
                sendAndWait(type, payload)
                appendLog("命令 0x%02X 已确认".format(type))
                runOnUiThread { setStatus("命令 0x%02X 已确认".format(type)) }
            } catch (e: Exception) { runOnUiThread { setStatus("发送失败：${e.message}") } }
        }
    }

    private fun recognizeScoreImage(uri: Uri) {
        val duration = scoreDurationInput.text.toString().toIntOrNull()
        if (duration == null || duration !in 1..65535) {
            setStatus("请先填写默认时值：1～65535，单位 10 ms")
            return
        }
        var bitmap: Bitmap? = null
        val input = try {
            if (Build.VERSION.SDK_INT >= 28) {
                bitmap = ImageDecoder.decodeBitmap(ImageDecoder.createSource(contentResolver, uri)) { decoder, info, _ ->
                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    val maxSide = maxOf(info.size.width, info.size.height)
                    if (maxSide > 2400) {
                        val factor = 2400.0 / maxSide
                        decoder.setTargetSize(
                            (info.size.width * factor).toInt().coerceAtLeast(1),
                            (info.size.height * factor).toInt().coerceAtLeast(1)
                        )
                    }
                }
                InputImage.fromBitmap(bitmap!!, 0)
            } else InputImage.fromFilePath(this, uri)
        }
        catch (e: Exception) { setStatus("无法读取图片：${e.message}"); return }
        if (bitmap != null) scoreImagePreview.setImageBitmap(bitmap) else scoreImagePreview.setImageURI(uri)
        scoreImagePreview.visibility = View.VISIBLE
        setStatus("正在识别简谱数字，请稍候…")
        val decoded = bitmap
        if (decoded != null) {
            imageExecutor.execute {
                val printed = try { PrintedScoreReader.read(decoded) } catch (_: Exception) { null }
                runOnUiThread {
                    if (printed != null) {
                        scoreInput.setText(printed.formatted(duration))
                        setStatus("识别到 ${printed.pitches.size} 个音符，共 ${printed.rowSizes.size} 行（每行 ${printed.rowSizes.joinToString("/")}）；高八度 1 映射 K8 共 ${printed.highDoCount} 处。请核对时值，再上传。")
                    } else recognizeScoreWithText(input, decoded, duration)
                }
            }
        } else recognizeScoreWithText(input, null, duration)
    }

    private fun recognizeScoreWithText(input: InputImage, bitmap: Bitmap?, duration: Int) {
        setStatus("版式未能完整匹配，正在尝试文字 OCR…")
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(input)
            .addOnSuccessListener { result ->
                var sevensFixed = 0
                val lines = result.textBlocks.flatMap { it.lines }.map { line ->
                    val correction = bitmap?.let { ScoreDigitShape.correct(it, line.boundingBox, line.text) }
                    sevensFixed += correction?.sevensFixed ?: 0
                    SimplifiedScoreParser.Line(
                        line.boundingBox?.top ?: Int.MAX_VALUE,
                        line.boundingBox?.left ?: Int.MAX_VALUE,
                        correction?.text ?: line.text,
                        line.boundingBox?.height() ?: 20
                    )
                }
                val draft = SimplifiedScoreParser.convert(lines, duration)
                if (draft.count == 0) {
                    setStatus("没有识别到连续的简谱数字。请换一张清晰、正向的图片，或手工输入曲谱。")
                } else {
                    if (draft.truncated) {
                        setStatus("识别结果超过 64 音，请裁剪曲谱分段识别；没有截断或覆盖当前曲谱。")
                        return@addOnSuccessListener
                    }
                    androidx.appcompat.app.AlertDialog.Builder(this)
                        .setTitle("核对识别结果：${draft.count} 音 / ${draft.rows.size} 行")
                        .setMessage(draft.rows.mapIndexed { index, row -> "${index + 1}. $row" }.joinToString("\n") +
                            "\n\n已按行从左到右排序。请对照原图，尤其检查漏音、7 和音区；时值统一为 $duration。")
                        .setPositiveButton("填入曲谱") { _, _ ->
                            scoreInput.setText(draft.formatted)
                            setStatus("已填入 ${draft.count} 音（各行 ${draft.rows.joinToString("/") { it.length.toString() }}）。请点击上传曲谱，成功后再开始指引。")
                        }
                        .setNegativeButton("取消", null)
                        .show()
                }
            }
            .addOnFailureListener { error -> setStatus("图片识别失败：${error.message}") }
            .addOnCompleteListener { recognizer.close() }
    }

    private fun uploadScore(raw: String) {
        val events = try {
            raw.split(',', ';', '\n').map { token ->
                val parts = token.trim().split(':')
                require(parts.size == 2)
                val pitch = parts[0].trim().toInt(); val duration = parts[1].trim().toInt()
                require(pitch in 0..7 && duration in 1..65535)
                pitch to duration
            }.filter { true }
        } catch (_: Exception) { setStatus("曲谱格式错误。示例：0:10,1:10,2:10"); return }
        if (events.isEmpty()) { setStatus("曲谱不能为空"); return }
        if (events.size > 64) { setStatus("曲谱最多支持 64 个音符"); return }
        commandExecutor.execute {
            try {
                synchronized(commandLock) {
                    sendAndWait(0x20)
                    for ((pitch, duration) in events) sendAndWait(0x21, Protocol.scoreEvent(pitch, duration))
                    sendAndWait(0x22)
                }
                runOnUiThread { setStatus("曲谱上传成功（${events.size} 个音符），可开始 LED 指引") }
            } catch (e: Exception) { runOnUiThread { setStatus("曲谱上传中断：${e.message}") } }
        }
    }

    private fun sendAndWait(type: Int, payload: ByteArray = byteArrayOf()): Int {
        synchronized(commandLock) {
            val stream = output ?: throw IllegalStateException("蓝牙未连接")
            synchronized(ackLock) {
                waitingAckFor = type
                waitingAckCode = null
            }
            try {
                synchronized(stream) { stream.write(Protocol.encode(type, payload)); stream.flush() }
                val result: Int?
                synchronized(ackLock) {
                    val deadline = System.currentTimeMillis() + 1800
                    while (waitingAckCode == null && System.currentTimeMillis() < deadline) {
                        val remaining = deadline - System.currentTimeMillis()
                        if (remaining > 0) ackLock.wait(remaining)
                    }
                    result = waitingAckCode
                }
                val ackCode = result ?: throw IllegalStateException("命令 0x%02X 等待 ACK 超时".format(type))
                if (ackCode != 0) throw IllegalStateException("FPGA 返回错误码 $ackCode（命令 0x%02X）".format(type))
                return type
            } finally {
                synchronized(ackLock) {
                    if (waitingAckFor == type) {
                        waitingAckFor = null
                        waitingAckCode = null
                    }
                }
            }
        }
    }

    private fun updateStats(force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastStatsUpdateMs < 250) return
        lastStatsUpdateMs = now
        val text = synchronized(pcmLock) {
            "有效帧 $goodFrames · 丢帧 $missingFrames · 校验/格式错误 $badFrames · ${(pcm16.size() / (recordingSampleRate * 2.0)).let { "%.1f".format(it) }} 秒"
        }
        runOnUiThread { stats.text = text }
    }

    private fun snapshotPcm(): ByteArray = synchronized(pcmLock) { pcm16.toByteArray() }
    private fun makeWav(pcm: ByteArray, sampleRate: Int): ByteArray {
        val header = ByteArrayOutputStream(44)
        fun ascii(s: String) { header.write(s.toByteArray(Charsets.US_ASCII)) }
        fun u16(v: Int) { header.write(v and 255); header.write((v ushr 8) and 255) }
        fun u32(v: Int) { repeat(4) { header.write((v ushr (8 * it)) and 255) } }
        ascii("RIFF"); u32(36 + pcm.size); ascii("WAVE"); ascii("fmt "); u32(16); u16(1); u16(1)
        u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16); ascii("data"); u32(pcm.size)
        return header.toByteArray() + pcm
    }
    private fun playRecording() {
        val pcm = snapshotPcm()
        if (pcm.isEmpty()) { setStatus("没有录音数据"); return }
        Thread {
            try {
                val file = File(cacheDir, "preview.wav")
                FileOutputStream(file).use { it.write(makeWav(pcm, recordingSampleRate)) }
                runOnUiThread {
                    mediaPlayer?.release()
                    mediaPlayer = MediaPlayer().apply {
                        setDataSource(file.absolutePath); prepare(); start()
                        setOnCompletionListener { it.release(); mediaPlayer = null }
                    }
                    setStatus("正在播放 WAV 试听")
                }
            } catch (e: Exception) { runOnUiThread { setStatus("播放失败：${e.message}") } }
        }.start()
    }
    private fun saveWav(uri: Uri) {
        val pcm = snapshotPcm()
        if (pcm.isEmpty()) { setStatus("没有录音数据可保存"); return }
        Thread {
            try {
                contentResolver.openOutputStream(uri)?.use { it.write(makeWav(pcm, recordingSampleRate)) } ?: error("无法创建文件")
                runOnUiThread { setStatus("WAV 已保存：${uri.lastPathSegment ?: "文件"}") }
            } catch (e: Exception) { runOnUiThread { setStatus("保存失败：${e.message}") } }
        }.start()
    }

    private fun appendLog(message: String) {
        runOnUiThread {
            log.append(message).append('\n')
            if (log.length > 3000) log.delete(0, log.length - 2500)
            logView.text = log.toString()
        }
    }
    private fun setStatus(message: String) { if (::status.isInitialized) status.text = message }
    private fun disconnect() { disconnectInternal(); connectButton.text = "连接 JDY-31"; setStatus("已断开") }
    private fun disconnectInternal() {
        reading.set(false); connected.set(false)
        modeConfirmed = false
        octaveConfirmed = false
        runOnUiThread { updateModeButtons(); updateOctaveButtons() }
        try { socket?.close() } catch (_: Exception) { }
        socket = null; output = null
    }
    override fun onDestroy() {
        disconnectInternal()
        commandExecutor.shutdownNow()
        imageExecutor.shutdownNow()
        mediaPlayer?.release(); mediaPlayer = null
        super.onDestroy()
    }
}
