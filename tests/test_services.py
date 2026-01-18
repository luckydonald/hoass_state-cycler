"""Tests for Plugin Template services."""
import pytest
from unittest.mock import Mock, AsyncMock
from homeassistant.core import HomeAssistant, ServiceCall
from custom_components.plugin_template.services import (
    async_setup_services,
    async_unload_services,
)


@pytest.fixture
def hass():
    """Create a mock Home Assistant instance."""
    hass_mock = Mock(spec=HomeAssistant)
    hass_mock.services = Mock()
    hass_mock.services.async_register = AsyncMock()
    hass_mock.services.async_remove = AsyncMock()
    return hass_mock


@pytest.mark.asyncio
async def test_async_setup_services(hass):
    """Test service setup."""
    await async_setup_services(hass)

    # Since the template has no services yet, this just verifies it doesn't crash
    assert True


@pytest.mark.asyncio
async def test_async_unload_services(hass):
    """Test service unload."""
    await async_unload_services(hass)

    # Since the template has no services yet, this just verifies it doesn't crash
    assert True

