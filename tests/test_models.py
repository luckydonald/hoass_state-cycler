"""Tests for Plugin Template data models."""
from custom_components.plugin_template.models import PluginData


def test_plugin_data_creation():
    """Test creating a PluginData instance."""
    data = PluginData()

    # Since it's an empty dataclass, just verify it exists
    assert data is not None
    assert isinstance(data, PluginData)


def test_plugin_data_is_dataclass():
    """Test that PluginData is a dataclass."""
    import dataclasses

    assert dataclasses.is_dataclass(PluginData)

