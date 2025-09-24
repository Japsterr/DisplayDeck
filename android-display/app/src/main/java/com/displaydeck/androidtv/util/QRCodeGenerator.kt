package com.displaydeck.androidtv.util

import android.graphics.Bitmap
import android.graphics.Color
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import java.util.*

object QRCodeGenerator {
    
    fun generateQRCode(
        content: String, 
        width: Int, 
        height: Int
    ): Bitmap? {
        return try {
            val writer = QRCodeWriter()
            val hints = EnumMap<EncodeHintType, Any>(EncodeHintType::class.java).apply {
                put(EncodeHintType.CHARACTER_SET, "UTF-8")
                put(EncodeHintType.MARGIN, 1)
            }
            
            val bitMatrix = writer.encode(content, BarcodeFormat.QR_CODE, width, height, hints)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
            
            for (x in 0 until width) {
                for (y in 0 until height) {
                    bitmap.setPixel(
                        x, y, 
                        if (bitMatrix[x, y]) Color.BLACK else Color.WHITE
                    )
                }
            }
            
            bitmap
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}