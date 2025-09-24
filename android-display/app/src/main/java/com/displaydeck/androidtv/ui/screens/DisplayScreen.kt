package com.displaydeck.androidtv.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.displaydeck.androidtv.ui.components.*
import com.displaydeck.androidtv.ui.viewmodel.DisplayViewModel

@Composable
fun DisplayScreen(
    viewModel: DisplayViewModel,
    onUnpair: () -> Unit
) {
    val displayState by viewModel.displayState.collectAsState()
    
    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        // Status bar at top
        StatusIndicatorBar(
            isConnected = displayState.isConnected,
            lastUpdated = displayState.lastUpdated,
            modifier = Modifier.padding(16.dp)
        )
        
        when {
            displayState.isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    LoadingIndicator(
                        message = "Loading menu...",
                        modifier = Modifier.padding(32.dp)
                    )
                }
            }
            
            displayState.error != null -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    verticalArrangement = Arrangement.Center
                ) {
                    ErrorBanner(
                        message = displayState.error,
                        onRetry = { viewModel.retryConnection() },
                        onDismiss = { viewModel.clearError() }
                    )
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    Button(
                        onClick = onUnpair,
                        modifier = Modifier.align(Alignment.CenterHorizontally)
                    ) {
                        Text("Return to Pairing")
                    }
                }
            }
            
            displayState.categories.isEmpty() -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Card(
                        modifier = Modifier.padding(32.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant
                        )
                    ) {
                        Column(
                            modifier = Modifier.padding(32.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "No menu items available",
                                style = MaterialTheme.typography.headlineMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center
                            )
                            
                            Spacer(modifier = Modifier.height(8.dp))
                            
                            Text(
                                text = "Please check your menu configuration in the DisplayDeck app",
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center
                            )
                        }
                    }
                }
            }
            
            else -> {
                // Display the menu
                MenuDisplay(
                    categories = displayState.categories,
                    businessName = displayState.businessName ?: "DisplayDeck",
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}