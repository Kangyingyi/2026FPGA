package cn.codex.fpga_music

import android.graphics.Bitmap
import android.graphics.Rect
import kotlin.math.max
import kotlin.math.min

/** A second pass for printed numbered notation, aimed at the common 7 -> 1/5 OCR error. */
internal object ScoreDigitShape {
    data class Correction(val text: String, val sevensFixed: Int)
    private data class Glyph(val left: Int, val top: Int, val right: Int, val bottom: Int, val area: Int) {
        val width get() = right - left + 1
        val height get() = bottom - top + 1
    }

    fun correct(bitmap: Bitmap, box: Rect?, ocrText: String): Correction {
        if (box == null) return Correction(ocrText, 0)
        val numberPositions = ocrText.indices.filter { ocrText[it] in '1'..'7' }
        if (numberPositions.size < 2) return Correction(ocrText, 0)
        val left = max(0, box.left - 3)
        val top = max(0, box.top - 3)
        val right = min(bitmap.width, box.right + 3)
        val bottom = min(bitmap.height, box.bottom + 3)
        val width = right - left
        val height = bottom - top
        if (width < 20 || height < 20 || width.toLong() * height > 2_000_000L) return Correction(ocrText, 0)

        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, left, top, width, height)
        val gray = IntArray(pixels.size)
        val histogram = IntArray(256)
        for (i in pixels.indices) {
            val p = pixels[i]
            val v = ((p ushr 16 and 255) * 77 + (p ushr 8 and 255) * 150 + (p and 255) * 29) ushr 8
            gray[i] = v
            histogram[v]++
        }
        val threshold = otsu(histogram, gray.size).coerceIn(60, 210)
        val dark = BooleanArray(gray.size) { gray[it] <= threshold }
        val seen = BooleanArray(dark.size)
        val queue = IntArray(dark.size)
        val glyphs = ArrayList<Glyph>()
        for (start in dark.indices) {
            if (!dark[start] || seen[start]) continue
            var head = 0
            var tail = 1
            queue[0] = start
            seen[start] = true
            var minX = start % width; var maxX = minX
            var minY = start / width; var maxY = minY
            while (head < tail) {
                val pos = queue[head++]
                val x = pos % width
                val y = pos / width
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                for (dy in -1..1) for (dx in -1..1) {
                    if (dx == 0 && dy == 0) continue
                    val nx = x + dx; val ny = y + dy
                    if (nx !in 0 until width || ny !in 0 until height) continue
                    val next = ny * width + nx
                    if (dark[next] && !seen[next]) { seen[next] = true; queue[tail++] = next }
                }
            }
            val glyph = Glyph(minX, minY, maxX, maxY, tail)
            if (glyph.height >= max(16, height * 42 / 100) &&
                glyph.width >= max(6, height * 12 / 100) &&
                glyph.area >= max(60, height * height / 65)) glyphs.add(glyph)
        }
        glyphs.sortBy { it.left }
        // OCR sometimes renders a printed 7 as T/Z instead of another digit.
        val letterPositions = ocrText.indices.filter { ocrText[it] in "TtZzIil?" }
        val positions = when {
            glyphs.size == numberPositions.size -> numberPositions
            letterPositions.size <= 2 && glyphs.size == numberPositions.size + letterPositions.size ->
                (numberPositions + letterPositions).sorted()
            else -> return Correction(ocrText, 0)
        }
        val chars = ocrText.toCharArray()
        var corrected = 0
        for (i in glyphs.indices) {
            if (looksLikeSeven(glyphs[i], dark, width) && chars[positions[i]] != '7') {
                chars[positions[i]] = '7'
                corrected++
            }
        }
        return Correction(String(chars), corrected)
    }

    private fun looksLikeSeven(glyph: Glyph, mask: BooleanArray, stride: Int): Boolean {
        val w = glyph.width; val h = glyph.height
        if (w * 100 < h * 50 || glyph.area * 100 >= w * h * 44) return false
        fun band(from: Int, to: Int): Pair<Double, Double> {
            val y0 = glyph.top + h * from / 100
            val y1 = max(y0 + 1, glyph.top + h * to / 100)
            var ink = 0; var sumX = 0
            for (y in y0 until min(y1, glyph.bottom + 1)) for (x in glyph.left..glyph.right) {
                if (mask[y * stride + x]) { ink++; sumX += x - glyph.left }
            }
            val size = max(1, min(y1, glyph.bottom + 1) - y0) * w
            return (ink.toDouble() / size) to (if (ink == 0) 0.0 else sumX.toDouble() / ink / w)
        }
        val upper = band(0, 20)
        val upperMiddle = band(20, 40)
        val lower = band(80, 100)
        return upper.first > 0.58 && upperMiddle.second > 0.58 &&
            lower.first < 0.42 && lower.second < 0.43
    }

    private fun otsu(hist: IntArray, total: Int): Int {
        var sum = 0L
        for (i in hist.indices) sum += i.toLong() * hist[i]
        var background = 0; var backgroundSum = 0L
        var best = -1.0; var threshold = 127
        for (i in hist.indices) {
            background += hist[i]
            if (background == 0) continue
            val foreground = total - background
            if (foreground == 0) break
            backgroundSum += i.toLong() * hist[i]
            val delta = backgroundSum.toDouble() / background - (sum - backgroundSum).toDouble() / foreground
            val variance = background.toDouble() * foreground * delta * delta
            if (variance > best) { best = variance; threshold = i }
        }
        return threshold
    }
}
