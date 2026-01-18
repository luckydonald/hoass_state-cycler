"""Tests for Plugin Template constants."""
from custom_components.plugin_template.const import DOMAIN, LOG_NAME


def test_domain_constant():
    """Test that DOMAIN is set correctly."""
    assert DOMAIN == "plugin_template"
    assert isinstance(DOMAIN, str)


def test_log_name_constant():
    """Test that LOG_NAME is set correctly."""
    assert LOG_NAME == "custom-components.plugin_template"
    assert isinstance(LOG_NAME, str)
    assert DOMAIN in LOG_NAME


def test_constants_are_final():
    """Test that constants appear to be final (by convention)."""
    # This is more of a documentation test
    # Python doesn't enforce Final at runtime
    assert DOMAIN is not None
    assert LOG_NAME is not None

