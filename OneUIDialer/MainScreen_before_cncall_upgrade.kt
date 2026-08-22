package com.oneui.dialer.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.oneui.dialer.model.CallLog
import com.oneui.dialer.model.CallType
import com.oneui.dialer.model.Contact

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen() {
    var selectedTab by remember { mutableStateOf(0) } // 0: Keypad, 1: Recents, 2: Contacts
    var dialedNumber by remember { mutableStateOf("") }

    val sampleContacts = listOf(
        Contact("1", "hehsam AL-Mahfaly", "772358226", true),
        Contact("2", "حذيفه المطوع", "733445566", true),
        Contact("3", "المجموعات", "", false),
        Contact("4", "عليا", "711223344", false),
        Contact("5", "خدمة وباقات 2G/3G", "133", false),
        Contact("6", "خدمة وباقات 4G/5G", "134", false)
    )

    val sampleLogs = listOf(
        CallLog("1", "9", "١٢:٥٥ ص", CallType.OUTGOING),
        CallLog("2", "772358226#", "١٢:٥٢ ص", CallType.OUTGOING, "اليمن"),
        CallLog("3", "1", "١٠:٥١ م", CallType.OUTGOING),
        CallLog("4", "20", "١٠:٥١ م", CallType.OUTGOING),
        CallLog("5", "اكرم العنسي (٢)", "١٠:٠٠ م", CallType.MISSED),
        CallLog("6", "لينك صخر", "٨:٤٥ م", CallType.OUTGOING)
    )

    Scaffold(
        containerColor = Color.Black,
        topBar = {
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    alignment = Alignment.CenterVertically
                ) {
                    Text("الهاتف", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Icon(Icons.Default.MoreVert, contentDescription = null, tint = Color.White)
                        Icon(Icons.Default.Search, contentDescription = null, tint = Color.White)
                        if (selectedTab == 2) Icon(Icons.Default.Add, contentDescription = null, tint = Color.White)
                        if (selectedTab == 1) Icon(Icons.Default.FilterList, contentDescription = null, tint = Color.White)
                    }
                }
                if (selectedTab == 2) {
                    Text("٧٢٠ جهة اتصال مزودة بأرقام هواتف", color = Color.Gray, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp))
                }
            }
        },
        bottomBar = {
            Column(modifier = Modifier.background(Color.Black)) {
                // Bottom Navigation Tabs matching One UI style
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceAround
                ) {
                    Text(
                        "لوحة المفاتيح",
                        color = if (selectedTab == 0) Color.White else Color.Gray,
                        fontSize = 15.sp,
                        fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal,
                        modifier = Modifier.clickable { selectedTab = 0 }
                    )
                    Text(
                        "سجل",
                        color = if (selectedTab == 1) Color.White else Color.Gray,
                        fontSize = 15.sp,
                        fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal,
                        modifier = Modifier.clickable { selectedTab = 1 }
                    )
                    Text(
                        "جهات الاتصال",
                        color = if (selectedTab == 2) Color.White else Color.Gray,
                        fontSize = 15.sp,
                        fontWeight = if (selectedTab == 2) FontWeight.Bold else FontWeight.Normal,
                        modifier = Modifier.clickable { selectedTab = 2 }
                    )
                }
                // Android Navigation Bar Indicator
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .width(100.dp)
                            .height(4.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(Color.White.copy(alpha = 0.6f))
                    )
                }
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when (selectedTab) {
                0 -> KeypadScreen(dialedNumber, onNumberChanged = { dialedNumber = it })
                1 -> RecentsScreen(sampleLogs)
                2 -> ContactsScreen(sampleContacts)
            }
        }
    }
}

@Composable
fun KeypadScreen(dialedNumber: String, onNumberChanged: (String) -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.Bottom,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = dialedNumber,
            color = Color.White,
            fontSize = 36.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(bottom = 24.dp)
        )

        val buttons = listOf(
            listOf("1", "2", "3"),
            listOf("4", "5", "6"),
            listOf("7", "8", "9"),
            listOf("*", "0", "#")
        )

        buttons.forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                row.forEach { digit ->
                    IconButton(
                        onClick = { onNumberChanged(dialedNumber + digit) },
                        modifier = Modifier.size(72.dp)
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(text = digit, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Light)
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Call Button (Green One UI)
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(Color(0xFF00E676))
                .clickable { /* Trigger Call */ },
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Default.Call, contentDescription = "Call", tint = Color.Black, modifier = Modifier.size(32.dp))
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
fun RecentsScreen(logs: List<CallLog>) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        item { Text("اليوم", color = Color.Gray, fontSize = 13.sp, modifier = Modifier.padding(vertical = 8.dp)) }
        items(logs.take(2)) { log -> CallLogItem(log) }
        item { Text("أمس", color = Color.Gray, fontSize = 13.sp, modifier = Modifier.padding(vertical = 8.dp)) }
        items(logs.drop(2)) { log -> CallLogItem(log) }
    }
}

@Composable
fun CallLogItem(log: CallLog) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1C1C1E))
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            alignment = Alignment.CenterVertically
        ) {
            Column {
                Text(log.nameOrNumber, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
                Row {
                    if (log.simCard != null) Text("${log.simCard} • ", color = Color.Gray, fontSize = 12.sp)
                    Text(log.time, color = Color.Gray, fontSize = 12.sp)
                }
            }
            Icon(Icons.Default.CallReceived, contentDescription = null, tint = Color(0xFF00E676), modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
fun ContactsScreen(contacts: List<Contact>) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        items(contacts) { contact ->
            Card(
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = Color(0xFF1C1C1E))
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(Color(0xFFFFAB91)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = contact.name.take(1),
                            color = Color.Black,
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp
                        )
                    }
                    Spacer(modifier = Modifier.width(16.dp))
                    Text(
                        text = contact.name,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    }
}
