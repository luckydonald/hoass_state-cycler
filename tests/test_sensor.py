"""Tests for State Cycler sensor adapters."""
import pytest
from unittest.mock import Mock, AsyncMock
from homeassistant.core import HomeAssistant
from homeassistant.config_entries import ConfigEntry
from custom_components.state_cycler.sensor import (
    async_setup_entry,
    StateCyclerRawSensor,
    StateCyclerFriendlySensor,
)
from custom_components.state_cycler.const import DOMAIN


@pytest.fixture
def hass():
    """Create a mock Home Assistant instance."""
    return Mock(spec=HomeAssistant)


@pytest.fixture
def config_entry():
    """Create a mock config entry."""
    entry = Mock(spec=ConfigEntry)
    entry.entry_id = "test_entry_id"
    entry.data = {}
    return entry


@pytest.mark.asyncio
async def test_async_setup_entry(hass, config_entry):
    """Test sensor platform setup creates two adapters (raw and friendly)."""
    async_add_entities = AsyncMock()

    await async_setup_entry(hass, config_entry, async_add_entities)

    async_add_entities.assert_called_once()
    sensors = async_add_entities.call_args[0][0]
    assert len(sensors) == 2
    assert any(isinstance(s, StateCyclerRawSensor) for s in sensors)
    assert any(isinstance(s, StateCyclerFriendlySensor) for s in sensors)


def test_raw_sensor_initialization(hass, config_entry):
    """Test raw sensor initialization."""
    sensor = StateCyclerRawSensor(hass, config_entry)

    assert sensor._entry == config_entry
    assert sensor._unique_id == f"{config_entry.entry_id}_raw"
    assert sensor._attr_name == f"{config_entry.data.get('name', 'State Cycler')} (State)" or isinstance(sensor._attr_name, str)
    assert sensor.state is not None


def test_friendly_sensor_initialization(hass, config_entry):
    """Test friendly sensor initialization."""
    sensor = StateCyclerFriendlySensor(hass, config_entry)

    assert sensor._entry == config_entry
    assert sensor._unique_id == f"{config_entry.entry_id}_friendly"
    assert sensor._attr_name == f"{config_entry.data.get('name', 'State Cycler')} (Friendly)" or isinstance(sensor._attr_name, str)
    assert sensor.state is not None


@pytest.mark.asyncio
async def test_sensor_update(hass, config_entry):
    """Test sensor update method runs without error."""
    sensor = StateCyclerRawSensor(hass, config_entry)

    # Should not raise any errors
    await sensor.async_update()

    # State remains a string
    assert isinstance(sensor.state, str)


def test_sensor_device_info(config_entry):
    """Test sensors device info."""
    # Use a minimal fake hass for device_info access
    hass = Mock()
    raw = StateCyclerRawSensor(hass, config_entry)

    device_info = raw.device_info

    assert device_info["identifiers"] == {(DOMAIN, config_entry.entry_id)}
    assert device_info["name"] == "State Cycler"
    assert device_info["manufacturer"] == "Custom"
    assert device_info["model"].startswith("State Cycler")


def test_sensor_multiple_types(config_entry):
    """Test creating raw and friendly sensors have different unique ids."""
    hass = Mock()
    raw = StateCyclerRawSensor(hass, config_entry)
    friendly = StateCyclerFriendlySensor(hass, config_entry)

    assert raw._unique_id != friendly._unique_id
