package com.displaydeck.androidtv.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.displaydeck.androidtv.data.model.MenuCategory
import com.displaydeck.androidtv.data.repository.DisplayRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DisplayState(
    val isLoading: Boolean = false,
    val isConnected: Boolean = false,
    val businessName: String? = null,
    val menuName: String? = null,
    val categories: List<MenuCategory> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class DisplayViewModel @Inject constructor(
    private val displayRepository: DisplayRepository
) : ViewModel() {
    
    private val _displayState = MutableStateFlow(DisplayState())
    val displayState: StateFlow<DisplayState> = _displayState.asStateFlow()
    
    init {
        loadDisplayData()
        connectToWebSocket()
    }
    
    private fun loadDisplayData() {
        viewModelScope.launch {
            _displayState.value = _displayState.value.copy(isLoading = true, error = null)
            
            try {
                val businessInfo = displayRepository.getBusinessInfo()
                val menuData = displayRepository.getMenuData()
                
                _displayState.value = _displayState.value.copy(
                    isLoading = false,
                    businessName = businessInfo.name,
                    menuName = menuData.name,
                    categories = menuData.categories
                )
                
            } catch (e: Exception) {
                _displayState.value = _displayState.value.copy(
                    isLoading = false,
                    error = "Failed to load display data: ${e.message}"
                )
            }
        }
    }
    
    private fun connectToWebSocket() {
        viewModelScope.launch {
            try {
                displayRepository.connectToWebSocket().collect { update ->
                    when (update.type) {
                        "connection_status" -> {
                            _displayState.value = _displayState.value.copy(
                                isConnected = update.data.getBoolean("connected")
                            )
                        }
                        "menu_update" -> {
                            // Reload menu data when updated
                            loadDisplayData()
                        }
                        "business_update" -> {
                            _displayState.value = _displayState.value.copy(
                                businessName = update.data.getString("name")
                            )
                        }
                    }
                }
            } catch (e: Exception) {
                _displayState.value = _displayState.value.copy(
                    error = "WebSocket connection failed: ${e.message}",
                    isConnected = false
                )
            }
        }
    }
    
    fun refreshData() {
        loadDisplayData()
    }
    
    fun reconnectWebSocket() {
        connectToWebSocket()
    }
}