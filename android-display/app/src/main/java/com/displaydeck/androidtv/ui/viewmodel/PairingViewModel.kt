package com.displaydeck.androidtv.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.displaydeck.androidtv.data.repository.PairingRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PairingState(
    val isLoading: Boolean = false,
    val pairingToken: String? = null,
    val isPaired: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class PairingViewModel @Inject constructor(
    private val pairingRepository: PairingRepository
) : ViewModel() {
    
    private val _pairingState = MutableStateFlow(PairingState())
    val pairingState: StateFlow<PairingState> = _pairingState.asStateFlow()
    
    init {
        generatePairingToken()
    }
    
    private fun generatePairingToken() {
        viewModelScope.launch {
            _pairingState.value = _pairingState.value.copy(isLoading = true, error = null)
            
            try {
                val token = pairingRepository.generatePairingToken()
                _pairingState.value = _pairingState.value.copy(
                    isLoading = false,
                    pairingToken = token
                )
                
                // Start listening for pairing completion
                listenForPairing(token)
                
            } catch (e: Exception) {
                _pairingState.value = _pairingState.value.copy(
                    isLoading = false,
                    error = "Failed to generate pairing token: ${e.message}"
                )
            }
        }
    }
    
    private fun listenForPairing(token: String) {
        viewModelScope.launch {
            try {
                pairingRepository.waitForPairing(token).collect { isPaired ->
                    if (isPaired) {
                        _pairingState.value = _pairingState.value.copy(
                            isPaired = true,
                            error = null
                        )
                    }
                }
            } catch (e: Exception) {
                _pairingState.value = _pairingState.value.copy(
                    error = "Pairing failed: ${e.message}"
                )
            }
        }
    }
    
    fun retryPairing() {
        generatePairingToken()
    }
}