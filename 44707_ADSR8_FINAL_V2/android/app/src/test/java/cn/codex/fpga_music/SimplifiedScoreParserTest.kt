package cn.codex.fpga_music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SimplifiedScoreParserTest {
    @Test fun mergesJitteredLeftRightFragmentsBeforeReadingNextRow() {
        // OCR bounding boxes model the supplied Mixue score: right-hand blocks
        // can be a few pixels higher than the left-hand block of the same row.
        val result = SimplifiedScoreParser.convert(listOf(
            SimplifiedScoreParser.Line(198, 450, "1233221", 30),
            SimplifiedScoreParser.Line(100, 100, "3556531", 30),
            SimplifiedScoreParser.Line(397, 450, "1233221", 30),
            SimplifiedScoreParser.Line(200, 100, "3556531", 30),
            SimplifiedScoreParser.Line(98, 450, "1233212", 30),
            SimplifiedScoreParser.Line(300, 200, "4446", 30),
            SimplifiedScoreParser.Line(297, 450, "5532", 30),
            SimplifiedScoreParser.Line(400, 100, "3556531", 30),
            SimplifiedScoreParser.Line(0, 0, "10:13", 30),
            SimplifiedScoreParser.Line(0, 500, "65%", 30),
            SimplifiedScoreParser.Line(500, 500, "123", 8),
            SimplifiedScoreParser.Line(550, 500, "97", 30),
            SimplifiedScoreParser.Line(600, 500, "12", 30)
        ), 50)
        val expected = listOf("35565311233212", "35565311233221", "44465532", "35565311233221")
        assertEquals(expected, result.rows)
        assertEquals(50, result.count)
        assertEquals(expected.joinToString("").map { "${it.digitToInt() - 1}:50" }.joinToString(","), result.formatted)
    }

    @Test fun keepsSingleNoteFragmentsAndDoesNotMergeAdjacentRows() {
        val result = SimplifiedScoreParser.convert(listOf(
            SimplifiedScoreParser.Line(101, 200, "7", 20),
            SimplifiedScoreParser.Line(100, 0, "123", 20),
            SimplifiedScoreParser.Line(130, 0, "456", 20)
        ), 10)
        assertEquals(listOf("1237", "456"), result.rows)
    }

    @Test fun doesNotExtractPartialMelodiesFromUnsupportedSymbols() {
        val result = SimplifiedScoreParser.convert(listOf(
            SimplifiedScoreParser.Line(100, 0, "1230"),
            SimplifiedScoreParser.Line(140, 0, "12T3"),
            SimplifiedScoreParser.Line(180, 0, "123:50")
        ), 50)
        assertEquals(0, result.count)
    }
    @Test fun ignoresLyricsAndPreservesScoreOrder() {
        val result = SimplifiedScoreParser.convert(listOf(
            SimplifiedScoreParser.Line(90, 10, "在你眼中我是谁"),
            SimplifiedScoreParser.Line(60, 100, "1 5 5 1 5 5 3"),
            SimplifiedScoreParser.Line(200, 0, "5 5 1 5 3 3")
        ), 50)
        assertEquals("0:50,4:50,4:50,0:50,4:50,4:50,2:50,4:50,4:50,0:50,4:50,2:50,2:50", result.formatted)
        assertEquals(13, result.count)
        assertFalse(result.truncated)
    }

    @Test fun truncatesAtFpgaCapacity() {
        val result = SimplifiedScoreParser.convert(listOf(
            SimplifiedScoreParser.Line(0, 0, "1".repeat(65))
        ), 10)
        assertEquals(64, result.count)
        assertTrue(result.truncated)
    }
}
