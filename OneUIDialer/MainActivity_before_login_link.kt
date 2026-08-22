package com.oneui.dialer

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.oneui.dialer.ui.screens.MainScreen
import com.oneui.dialer.ui.theme.OneUIDialerTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            OneUIDialerTheme {
                MainScreen()
            }
        }
    }
}
