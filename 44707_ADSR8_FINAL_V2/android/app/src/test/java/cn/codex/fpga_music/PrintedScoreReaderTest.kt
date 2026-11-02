package cn.codex.fpga_music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import javax.imageio.ImageIO

class PrintedScoreReaderTest {
    @Test fun readsEveryNoteFromTheSuppliedWholeImage() {
        val stream = javaClass.classLoader!!.getResourceAsStream("score_example.png")
        assertNotNull(stream)
        val image = ImageIO.read(stream)
        val pixels = IntArray(image.width * image.height)
        image.getRGB(0, 0, image.width, image.height, pixels, 0, image.width)
        val result = PrintedScoreReader.readPixels(image.width, image.height, pixels)
        assertNotNull(result)
        result!!
        assertEquals(listOf(7, 6, 6, 10, 7, 13), result.rowSizes)
        assertEquals(49, result.pitches.size)
        assertEquals(1, result.highDoCount)
        val expectedRows = listOf(
            "1551553", "551533", "555571", "3211112611", "1551553", "1551533555571"
        )
        val expected = expectedRows.flatMapIndexed { row, digits ->
            digits.mapIndexed { index, digit ->
                if (row == 2 && index == 5) 7 else digit.digitToInt() - 1
            }
        }
        assertEquals(expected, result.pitches)
    }
}
