"""Tests for Plugin Template integration."""
import pytest
from unittest.mock import Mock, patch, AsyncMock
from homeassistant.core import HomeAssistant
from homeassistant.config_entries import ConfigEntry
from custom_components.plugin_template import async_setup_entry, async_unload_entry
from custom_components.plugin_template.const import DOMAIN


@pytest.fixture
def hass():
    """Create a mock Home Assistant instance."""
    return Mock(spec=HomeAssistant)


@pytest.fixture
def config_entry():
    """Create a mock config entry."""
    entry = Mock(spec=ConfigEntry)
    entry.entry_id = "test_entry_id"
    entry.data = {"test": "data"}
    return entry


@pytest.mark.asyncio
async def test_async_setup_entry(hass, config_entry):
    """Test setting up the integration."""
    hass.data = {}
    hass.config_entries = Mock()
    hass.config_entries.async_forward_entry_setups = AsyncMock(return_value=True)

    result = await async_setup_entry(hass, config_entry)

    assert result is True
    assert DOMAIN in hass.data
    assert config_entry.entry_id in hass.data[DOMAIN]
    assert "config" in hass.data[DOMAIN][config_entry.entry_id]


@pytest.mark.asyncio
async def test_async_unload_entry(hass, config_entry):
    """Test unloading the integration."""
    hass.data = {DOMAIN: {config_entry.entry_id: {"config": {}}}}
    hass.config_entries = Mock()
    hass.config_entries.async_unload_platforms = AsyncMock(return_value=True)

    result = await async_unload_entry(hass, config_entry)

    assert result is True
    assert config_entry.entry_id not in hass.data[DOMAIN]


@pytest.mark.asyncio
async def test_async_unload_entry_failure(hass, config_entry):
    """Test unloading the integration when platforms fail to unload."""
    hass.data = {DOMAIN: {config_entry.entry_id: {"config": {}}}}
    hass.config_entries = Mock()
    hass.config_entries.async_unload_platforms = AsyncMock(return_value=False)

    result = await async_unload_entry(hass, config_entry)

    assert result is False
    assert config_entry.entry_id in hass.data[DOMAIN]

