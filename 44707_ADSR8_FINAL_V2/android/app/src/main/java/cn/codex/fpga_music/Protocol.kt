package cn.codex.fpga_music

import java.io.ByteArrayOutputStream

data class WireFrame(val type: Int, val payload: ByteArray)

object Protocol {
    private const val SYNC = 0xA5
    private const val MAX_PAYLOAD = 2048

    fun encode(type: Int, payload: ByteArray = byteArrayOf()): ByteArray {
        require(type in 0..255 && payload.size <= MAX_PAYLOAD)
        val out = ByteArrayOutputStream(payload.size + 5)
        out.write(SYNC)
        out.write(type)
        out.write(payload.size and 0xFF)
        out.write((payload.size ushr 8) and 0xFF)
        out.write(payload)
        var sum = type + (payload.size and 0xFF) + ((payload.size ushr 8) and 0xFF)
        payload.forEach { sum += it.toInt() and 0xFF }
        out.write(sum and 0xFF)
        return out.toByteArray()
    }

    fun u16(value: Int): ByteArray = byteArrayOf(value.toByte(), (value ushr 8).toByte())
    fun scoreEvent(pitch: Int, duration10ms: Int): ByteArray = byteArrayOf(
        pitch.toByte(), duration10ms.toByte(), (duration10ms ushr 8).toByte()
    )
}

/** Streaming parser: SPP reads arbitrary chunks, not one read per FPGA frame. */
class FrameParser(
    private val onFrame: (WireFrame) -> Unit,
    private val onBadFrame: () -> Unit,
    private val clockMs: () -> Long = { System.nanoTime() / 1_000_000 }
) {
    private val bytes = ArrayList<Int>()
    private var lastFeedMs = 0L

    @Synchronized
    fun feed(chunk: ByteArray, count: Int = chunk.size) {
        if (count == 0) return
        val now = clockMs()
        // A truncated final audio frame must not consume the next command ACK.
        if (bytes.isNotEmpty() && now - lastFeedMs > 500) {
            bytes.clear()
            onBadFrame()
        }
        lastFeedMs = now
        for (i in 0 until count) bytes.add(chunk[i].toInt() and 0xFF)
        while (true) {
            val sync = bytes.indexOf(0xA5)
            if (sync < 0) { bytes.clear(); return }
            if (sync > 0) repeat(sync) { bytes.removeAt(0) }
            if (bytes.size < 4) return
            val length = bytes[2] or (bytes[3] shl 8)
            // A damaged length must not hold the parser waiting indefinitely and
            // swallow later ACKs. These are the only FPGA-to-phone frame shapes.
            val validShape = when (bytes[1]) {
                0x7F -> length == 2 || length == 3
                0x42 -> length == 37
                0x41 -> length == 66 // Older PCM firmware.
                else -> false
            }
            if (!validShape) { bytes.removeAt(0); onBadFrame(); continue }
            val total = length + 5
            if (bytes.size < total) return
            var sum = bytes[1] + bytes[2] + bytes[3]
            for (i in 0 until length) sum += bytes[4 + i]
            if ((sum and 0xFF) != bytes[total - 1]) {
                bytes.removeAt(0)
                onBadFrame()
                continue
            }
            val type = bytes[1]
            val payload = ByteArray(length) { bytes[4 + it].toByte() }
            repeat(total) { bytes.removeAt(0) }
            onFrame(WireFrame(type, payload))
        }
    }
}

/** 0x42 format: seq:u16, predictor:i16, IMA index:u8, then 32 low-nibble-first bytes. */
object ImaAdpcm {
    private val steps = intArrayOf(
        7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,
        97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,
        724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,
        3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,
        15289,16818,18500,20350,22385,24623,27086,29794,32767
    )
    private val indexDelta = intArrayOf(-1,-1,-1,-1,2,4,6,8)

    fun decode(payload: ByteArray): Pair<Int, ShortArray>? {
        if (payload.size != 37) return null
        val seq = (payload[0].toInt() and 0xFF) or ((payload[1].toInt() and 0xFF) shl 8)
        var predictor = ((payload[2].toInt() and 0xFF) or (payload[3].toInt() shl 8)).toShort().toInt()
        var index = payload[4].toInt() and 0xFF
        if (index !in 0..88) return null
        val pcm = ShortArray(64)
        pcm[0] = predictor.toShort()
        for (sample in 1 until 64) {
            val packed = payload[5 + (sample - 1) / 2].toInt() and 0xFF
            val code = if ((sample - 1) % 2 == 0) packed and 0x0F else packed ushr 4
            val step = steps[index]
            var diff = step ushr 3
            if ((code and 1) != 0) diff += step ushr 2
            if ((code and 2) != 0) diff += step ushr 1
            if ((code and 4) != 0) diff += step
            predictor = (predictor + if ((code and 8) != 0) -diff else diff).coerceIn(-32768, 32767)
            index = (index + indexDelta[code and 7]).coerceIn(0, 88)
            pcm[sample] = predictor.toShort()
        }
        return seq to pcm
    }
}
