package cn.codex.fpga_music

import android.graphics.Bitmap
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Reads clean, high-resolution printed numbered scores without relying on OCR line detection. */
internal object PrintedScoreReader {
    data class Result(val pitches: List<Int>, val rowSizes: List<Int>, val highDoCount: Int) {
        fun formatted(durationUnits: Int) = pitches.joinToString(",") { "$it:$durationUnits" }
    }
    private data class Component(val x: Int, val y: Int, val w: Int, val h: Int, val area: Int) {
        val baseline get() = y + h
        val centerX get() = x + w / 2.0
    }
    private data class Note(val digit: Int, val dotCount: Int)

    private val templates: Map<Int, BooleanArray> by lazy {
        ScoreDigitTemplates.packed.mapValues { (_, encoded) ->
            val bytes = decodeBase64(encoded)
            BooleanArray(ScoreDigitTemplates.WIDTH * ScoreDigitTemplates.HEIGHT) { pos ->
                (bytes[pos / 8].toInt() and (1 shl (7 - pos % 8))) != 0
            }
        }
    }

    private fun decodeBase64(encoded: String): ByteArray {
        val alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        val output = ByteArray(ScoreDigitTemplates.WIDTH * ScoreDigitTemplates.HEIGHT / 8)
        var bits = 0; var pending = 0; var count = 0
        for (char in encoded) {
            if (char == '=') break
            val value = alphabet.indexOf(char)
            require(value >= 0)
            pending = (pending shl 6) or value
            bits += 6
            if (bits >= 8) {
                bits -= 8
                output[count++] = (pending ushr bits).toByte()
            }
        }
        require(count == output.size)
        return output
    }

    fun read(bitmap: Bitmap): Result? {
        val width = bitmap.width; val height = bitmap.height
        if (width < 300 || height < 300 || width.toLong() * height > 8_000_000L) return null
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        return readPixels(width, height, pixels)
    }

    internal fun readPixels(width: Int, height: Int, pixels: IntArray): Result? {
        if (width < 300 || height < 300 || width.toLong() * height > 8_000_000L || pixels.size != width * height) return null
        val histogram = IntArray(256)
        for (pixel in pixels) {
            val gray = ((pixel ushr 16 and 255) * 77 + (pixel ushr 8 and 255) * 150 + (pixel and 255) * 29) ushr 8
            histogram[gray]++
        }
        val threshold = otsu(histogram, pixels.size).coerceIn(60, 210)
        val dark = BooleanArray(pixels.size) { i ->
            val pixel = pixels[i]
            (((pixel ushr 16 and 255) * 77 + (pixel ushr 8 and 255) * 150 + (pixel and 255) * 29) ushr 8) <= threshold
        }
        val components = components(dark, width, height)
        val digitCandidates = components.filter { c ->
            val ratio = c.w.toDouble() / c.h
            val density = c.area.toDouble() / (c.w * c.h)
            c.h >= height * .025 && c.h <= height * .065 &&
                ratio in .28..0.90 && density in .24..0.75
        }
        val dots = components.filter { c ->
            c.h >= height * .004 && c.h <= height * .018 &&
                c.w >= height * .004 && c.w <= height * .018 && c.area >= 12
        }
        val groups = ArrayList<MutableList<Component>>()
        val tolerance = max(8.0, height * .007)
        for (candidate in digitCandidates.sortedBy { it.baseline }) {
            val group = groups.lastOrNull()
            if (group == null || abs(candidate.baseline - group.map { it.baseline }.average()) > tolerance)
                groups.add(mutableListOf(candidate))
            else group.add(candidate)
        }
        val rows = ArrayList<List<Component>>()
        for (group in groups) {
            if (group.size < 3) continue
            val medianHeight = group.map { it.h }.sorted()[group.size / 2]
            val aligned = group.filter { abs(it.h - medianHeight) < medianHeight * .16 }.sortedBy { it.x }
            if (aligned.size < 3) continue
            val dotted = aligned.count { dotCount(it, dots) > 0 }
            if (dotted * 2 >= aligned.size) rows.add(aligned)
        }
        rows.sortBy { row -> row.minOf { it.y } }
        if (rows.isEmpty()) return null
        val notes = ArrayList<Note>()
        for (row in rows) for (glyph in row) {
            val digit = matchDigit(glyph, dark, width) ?: return null
            notes.add(Note(digit, dotCount(glyph, dots)))
        }
        val normalHighDots = notes.count { it.dotCount == 1 } > notes.size / 2
        var highDoCount = 0
        val pitches = notes.take(64).map {
            if (normalHighDots && it.digit == 1 && it.dotCount >= 2) {
                highDoCount++
                7
            } else it.digit - 1
        }
        return Result(pitches, rows.map { it.size }, highDoCount)
    }

    private fun dotCount(glyph: Component, dots: List<Component>): Int = dots.count { dot ->
        abs(dot.centerX - glyph.centerX) < glyph.h * .28 &&
            (glyph.y - (dot.y + dot.h)) > 3 &&
            (glyph.y - (dot.y + dot.h)) < glyph.h * .75
    }

    private fun matchDigit(glyph: Component, mask: BooleanArray, stride: Int): Int? {
        val normalized = BooleanArray(ScoreDigitTemplates.WIDTH * ScoreDigitTemplates.HEIGHT)
        for (dy in 0 until ScoreDigitTemplates.HEIGHT) {
            val y = glyph.y + dy * glyph.h / ScoreDigitTemplates.HEIGHT
            for (dx in 0 until ScoreDigitTemplates.WIDTH) {
                val x = glyph.x + dx * glyph.w / ScoreDigitTemplates.WIDTH
                normalized[dy * ScoreDigitTemplates.WIDTH + dx] = mask[y * stride + x]
            }
        }
        val ranked = templates.map { (digit, reference) ->
            val difference = normalized.indices.count { normalized[it] != reference[it] }
            digit to difference.toDouble() / normalized.size
        }.sortedBy { it.second }
        // Unknown font or a printed '4': fall back to OCR instead of inventing a note.
        if (ranked[0].second > .15 || ranked[1].second - ranked[0].second < .08) return null
        return ranked[0].first
    }

    private fun components(mask: BooleanArray, width: Int, height: Int): List<Component> {
        val seen = BooleanArray(mask.size)
        val queue = IntArray(mask.size)
        val result = ArrayList<Component>()
        for (start in mask.indices) {
            if (!mask[start] || seen[start]) continue
            var head = 0; var tail = 1
            queue[0] = start; seen[start] = true
            var minX = start % width; var maxX = minX
            var minY = start / width; var maxY = minY
            while (head < tail) {
                val pos = queue[head++]
                val x = pos % width; val y = pos / width
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                for (dy in -1..1) for (dx in -1..1) {
                    if (dx == 0 && dy == 0) continue
                    val nx = x + dx; val ny = y + dy
                    if (nx !in 0 until width || ny !in 0 until height) continue
                    val next = ny * width + nx
                    if (mask[next] && !seen[next]) { seen[next] = true; queue[tail++] = next }
                }
            }
            if (tail >= 12) result.add(Component(minX, minY, maxX - minX + 1, maxY - minY + 1, tail))
        }
        return result
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
