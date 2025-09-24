package com.displaydeck.androidtv.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun StatusIndicatorBar(
    isConnected: Boolean,
    lastUpdated: String?,
    batteryLevel: Float? = null,
    signalStrength: Int? = null,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Connection Status
            ConnectionStatus(
                isConnected = isConnected,
                lastUpdated = lastUpdated
            )
            
            // System indicators
            Row(
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                signalStrength?.let {
                    SignalStrengthIndicator(strength = it)
                }
                
                batteryLevel?.let {
                    BatteryIndicator(level = it)
                }
                
                TimeDisplay()
            }
        }
    }
}

@Composable
fun ConnectionStatus(
    isConnected: Boolean,
    lastUpdated: String?
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Status indicator dot
        Surface(
            modifier = Modifier.size(12.dp),
            shape = CircleShape,
            color = if (isConnected) 
                MaterialTheme.colorScheme.tertiary 
            else 
                MaterialTheme.colorScheme.error
        ) {}
        
        Column {
            Text(
                text = if (isConnected) "Connected" else "Disconnected",
                style = MaterialTheme.typography.labelMedium.copy(
                    fontSize = 14.sp
                ),
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            
            lastUpdated?.let { timestamp ->
                Text(
                    text = "Last sync: ${formatTimestamp(timestamp)}",
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontSize = 12.sp
                    ),
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@Composable
fun SignalStrengthIndicator(strength: Int) {
    Row(
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        repeat(4) { index ->
            val barHeight = when (index) {
                0 -> 8.dp
                1 -> 12.dp
                2 -> 16.dp
                3 -> 20.dp
                else -> 8.dp
            }
            
            val isActive = index < (strength / 25) // Assuming strength is 0-100
            
            Surface(
                modifier = Modifier
                    .width(4.dp)
                    .height(barHeight),
                color = if (isActive) 
                    MaterialTheme.colorScheme.primary 
                else 
                    MaterialTheme.colorScheme.outline.copy(alpha = 0.3f),
                shape = RoundedCornerShape(2.dp)
            ) {}
        }
    }
}

@Composable
fun BatteryIndicator(level: Float) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = when {
                level > 0.75f -> Icons.Default.Battery90
                level > 0.5f -> Icons.Default.Battery60
                level > 0.25f -> Icons.Default.Battery30
                else -> Icons.Default.Battery20
            },
            contentDescription = "Battery Level",
            modifier = Modifier.size(16.dp),
            tint = when {
                level > 0.25f -> MaterialTheme.colorScheme.onSurfaceVariant
                else -> MaterialTheme.colorScheme.error
            }
        )
        
        Text(
            text = "${(level * 100).toInt()}%",
            style = MaterialTheme.typography.bodySmall.copy(
                fontSize = 12.sp
            ),
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
fun TimeDisplay() {
    val currentTime by remember {
        mutableStateOf(System.currentTimeMillis())
    }
    
    // Update time every minute
    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(60000) // 1 minute
            // Update time state here if needed
        }
    }
    
    val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    val dateFormat = SimpleDateFormat("MMM dd", Locale.getDefault())
    
    Column(
        horizontalAlignment = Alignment.End
    ) {
        Text(
            text = timeFormat.format(Date(currentTime)),
            style = MaterialTheme.typography.titleMedium.copy(
                fontSize = 18.sp
            ),
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Text(
            text = dateFormat.format(Date(currentTime)),
            style = MaterialTheme.typography.bodySmall.copy(
                fontSize = 12.sp
            ),
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
        )
    }
}

@Composable
fun ErrorBanner(
    message: String,
    onRetry: (() -> Unit)? = null,
    onDismiss: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Error,
                    contentDescription = "Error",
                    tint = MaterialTheme.colorScheme.onErrorContainer,
                    modifier = Modifier.size(24.dp)
                )
                
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontSize = 14.sp
                    ),
                    color = MaterialTheme.colorScheme.onErrorContainer,
                    modifier = Modifier.weight(1f)
                )
            }
            
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                onRetry?.let {
                    TextButton(
                        onClick = it,
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.onErrorContainer
                        )
                    ) {
                        Text("Retry")
                    }
                }
                
                onDismiss?.let {
                    IconButton(
                        onClick = it,
                        modifier = Modifier.size(24.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Dismiss",
                            tint = MaterialTheme.colorScheme.onErrorContainer,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun LoadingIndicator(
    message: String = "Loading...",
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(24.dp),
                color = MaterialTheme.colorScheme.primary,
                strokeWidth = 3.dp
            )
            
            Spacer(modifier = Modifier.width(16.dp))
            
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontSize = 16.sp
                ),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun formatTimestamp(timestamp: String): String {
    return try {
        // Assuming timestamp is in ISO format, adjust as needed
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
        val date = format.parse(timestamp) ?: Date()
        val displayFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        displayFormat.format(date)
    } catch (e: Exception) {
        "Unknown"
    }
}