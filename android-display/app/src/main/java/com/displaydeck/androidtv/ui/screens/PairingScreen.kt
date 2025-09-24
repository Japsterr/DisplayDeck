package com.displaydeck.androidtv.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.displaydeck.androidtv.ui.pairing.*
import com.displaydeck.androidtv.ui.viewmodel.PairingViewModel

@Composable
fun PairingScreen(
    viewModel: PairingViewModel,
    onPaired: () -> Unit
) {
    val pairingState by viewModel.pairingState.collectAsState()
    
    LaunchedEffect(pairingState.isPaired) {
        if (pairingState.isPaired) {
            onPaired()
        }
    }
    
    Row(
        modifier = Modifier
            .fillMaxSize()
            .padding(48.dp),
        horizontalArrangement = Arrangement.spacedBy(48.dp)
    ) {
        // Left side - Branding and Instructions
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // App branding
            Column(
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "DisplayDeck",
                    style = MaterialTheme.typography.displayLarge.copy(
                        fontSize = 64.sp
                    ),
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                Text(
                    text = "Digital Menu Display System",
                    style = MaterialTheme.typography.headlineMedium.copy(
                        fontSize = 24.sp
                    ),
                    color = MaterialTheme.colorScheme.onBackground
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text(
                    text = "Professional • Modern • Easy to Use",
                    style = MaterialTheme.typography.titleMedium.copy(
                        fontSize = 16.sp
                    ),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            // Pairing instructions
            PairingInstructions()
            
            // Device info
            DeviceInfo(
                deviceId = pairingState.deviceId ?: "Unknown"
            )
        }
        
        // Right side - QR Code and Status
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // QR Code
            pairingState.pairingToken?.let { token ->
                PairingQRCode(
                    pairingToken = token,
                    isLoading = pairingState.isLoading,
                    error = pairingState.error,
                    onRegenerateToken = { viewModel.regeneratePairingToken() }
                )
            } ?: run {
                PairingQRCode(
                    pairingToken = "",
                    isLoading = true,
                    error = pairingState.error,
                    onRegenerateToken = { viewModel.generatePairingToken() }
                )
            }
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // Pairing progress
            PairingProgress(
                isWaitingForPairing = pairingState.isLoading && pairingState.pairingToken != null,
                timeRemaining = pairingState.tokenExpiresIn
            )
            
            // Additional help text
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                )
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Need Help?",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    
                    Spacer(modifier = Modifier.height(8.dp))
                    
                    Text(
                        text = "Visit displaydeck.com/support for setup guides and troubleshooting",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    
                    Spacer(modifier = Modifier.height(12.dp))
                    
                    OutlinedButton(
                        onClick = { viewModel.regeneratePairingToken() },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Generate New QR Code")
                    }
                }
            }
        }
    }
}