<script setup lang="ts">
import {
  computed,
  onMounted,
  onUnmounted,
  ref,
} from 'vue';
import type {
  CardConfig,
  HomeAssistant,
} from './types';

// Props
const props = defineProps<{
  hass: HomeAssistant | null;
  config: CardConfig;
}>();

// State
const currentTime = ref(new Date());
let timeInterval: ReturnType<typeof setInterval> | null = null;

// Lifecycle
onMounted(() => {
  timeInterval = setInterval(() => {
    currentTime.value = new Date();
  }, 1000);
});

onUnmounted(() => {
  if (timeInterval) {
    clearInterval(timeInterval);
  }
});

// Computed
const cardTitle = computed(() => props.config.title || 'Plugin Template');

// Helper to get entity state
const getEntityState = (entityId: string) => {
  if (!props.hass || !props.hass.states) return null;
  return props.hass.states[entityId];
};

// Helper to call service
async function callService(domain: string, service: string, data: any = {}) {
  if (!props.hass) return;
  await props.hass.callService(domain, service, data);
}

// Format time for display
const formatTime = (date: Date): string => {
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};
</script>

<template>
  <ha-card>
    <div class="card-header">
      <div class="name">{{ cardTitle }}</div>
    </div>
    <div class="card-content">
      <!-- Example section: Display current time -->
      <div class="section">
        <h3>Current Time</h3>
        <p class="time-display">{{ formatTime(currentTime) }}</p>
      </div>

      <!-- Example section: Display entity if configured -->
      <div v-if="config.entity" class="section">
        <h3>Entity State</h3>
        <div v-if="getEntityState(config.entity)" class="entity-info">
          <p><strong>Entity:</strong> {{ config.entity }}</p>
          <p><strong>State:</strong> {{ getEntityState(config.entity)?.state }}</p>
        </div>
        <p v-else class="warning">Entity not found</p>
      </div>

      <!-- Placeholder for your custom content -->
      <div class="section">
        <p class="placeholder">
          This is a template card. Replace this content with your own implementation.
        </p>
      </div>
    </div>
  </ha-card>
</template>

<style scoped>
ha-card {
  padding: 16px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--divider-color);
}

.name {
  font-size: 24px;
  font-weight: 500;
  color: var(--primary-text-color);
}

.card-content {
  padding-top: 16px;
}

.section {
  margin-bottom: 24px;
}

.section:last-child {
  margin-bottom: 0;
}

.section h3 {
  margin: 0 0 12px 0;
  font-size: 16px;
  font-weight: 500;
  color: var(--primary-text-color);
}

.time-display {
  font-size: 32px;
  font-weight: 300;
  color: var(--primary-text-color);
  margin: 0;
}

.entity-info p {
  margin: 4px 0;
  color: var(--primary-text-color);
}

.placeholder {
  padding: 20px;
  background: var(--secondary-background-color);
  border-radius: 8px;
  text-align: center;
  color: var(--secondary-text-color);
  font-style: italic;
}

.warning {
  color: var(--error-color);
  font-style: italic;
}
</style>

