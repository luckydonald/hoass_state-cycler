"""Pytest configuration and fixtures for Plugin Template tests."""
import sys
from pathlib import Path

# Add the custom_components directory to the Python path
root_dir = Path(__file__).parent.parent
sys.path.insert(0, str(root_dir))

import pytest


@pytest.fixture(autouse=True)
def auto_enable_custom_integrations(enable_custom_integrations):
    """Enable custom integrations for all tests."""
    yield


@pytest.fixture
def mock_hass():
    """Return a mock Home Assistant instance."""
    from unittest.mock import Mock
    from homeassistant.core import HomeAssistant

    hass = Mock(spec=HomeAssistant)
    hass.data = {}
    return hass

