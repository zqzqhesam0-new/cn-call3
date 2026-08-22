package com.oneui.dialer.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val OneUIDarkColorScheme = darkColorScheme(
    primary = Color(0xFF00E676),
    onPrimary = Color.Black,
    background = Color(0xFF000000),
    surface = Color(0xFF121212),
    onSurface = Color.White,
    secondary = Color(0xFF2C2C2E)
)

@Composable
fun OneUIDialerTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = OneUIDarkColorScheme,
        content = content
    )
}
