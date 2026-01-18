<template>
  <ha-card>
    <div class="card-header">
      <div class="name">{{ cardTitle }}</div>
      <ha-icon-button
        v-if="config.entity"
        @click="toggleEditMode"
        class="edit-button"
      >
        <ha-icon :icon="editMode ? 'mdi:check' : 'mdi:pencil'" />
      </ha-icon-button>
    </div>

    <div v-if="!config.entity" class="card-content">
      <div class="warning">
        <ha-icon icon="mdi:alert" />
        <p>No entity configured. Please configure this card.</p>
      </div>
    </div>

    <div v-else-if="editMode" class="card-content edit-mode">
      <!-- Configuration editor -->
      <div class="section">
        <h3>Entities</h3>
        <div class="entity-list">
          <div
            v-for="(entityId, index) in configStates"
            :key="index"
            class="entity-item"
          >
            <span class="entity-name">{{ getEntityFriendlyName(entityId) }}</span>
            <span class="entity-id">{{ entityId }}</span>
            <div class="entity-actions">
              <ha-icon-button
                @click="moveEntityUp(index)"
                :disabled="index === 0"
              >
                <ha-icon icon="mdi:arrow-up" />
              </ha-icon-button>
              <ha-icon-button
                @click="moveEntityDown(index)"
                :disabled="index === configStates.length - 1"
              >
                <ha-icon icon="mdi:arrow-down" />
              </ha-icon-button>
              <ha-icon-button @click="removeEntity(index)">
                <ha-icon icon="mdi:delete" />
              </ha-icon-button>
            </div>
          </div>
        </div>
        <div class="add-entity">
          <input
            v-model="newEntityId"
            type="text"
            placeholder="Entity ID (e.g., light.living_room)"
            class="entity-input"
            @keyup.enter="addEntity"
          />
          <ha-button @click="addEntity">Add</ha-button>
        </div>
      </div>
      <div class="section">
        <h3>Options</h3>
        <div class="option">
          <label>
            <input
              v-model="configIncludeOffState"
              type="checkbox"
            />
            Include off state in cycle
          </label>
        </div>
        <div class="option">
          <label>
            Timer interval (seconds):
            <input
              v-model.number="configTimerInterval"
              type="number"
              min="0.1"
              step="0.1"
              placeholder="Optional"
              class="timer-input"
            />
          </label>
        </div>
      </div>
    </div>

    <div v-else class="card-content">
      <!-- Current state display -->
      <div class="section current-state">
        <div class="state-info">
          <div class="state-label">Current State:</div>
          <div class="state-value">{{ currentStateFriendly }}</div>
          <div class="state-index" v-if="currentIndex >= 0">
            Index: {{ currentIndex }} / {{ states.length - 1 }}
          </div>
        </div>
      </div>

      <!-- Control buttons -->
      <div class="section controls">
        <ha-button
          @click="handleToggle"
          :class="{ 'on': toggleState }"
          class="control-button toggle-button"
        >
          <ha-icon :icon="toggleState ? 'mdi:power' : 'mdi:power-off'" />
          {{ toggleState ? 'On' : 'Off' }}
        </ha-button>

        <ha-button
          @click="handleNext"
          class="control-button"
          :disabled="!toggleState && states.length === 0"
        >
          <ha-icon icon="mdi:skip-next" />
          Next
        </ha-button>

        <ha-button
          @click="handleCycle"
          class="control-button"
        >
          <ha-icon icon="mdi:sync" />
          Cycle
        </ha-button>
      </div>

      <!-- States list -->
      <div v-if="states.length > 0" class="section states-list">
        <h3>States</h3>
        <div
          v-for="(entityId, index) in states"
          :key="index"
          :class="{ 'active': index === currentIndex }"
          class="state-item"
          @click="handleToIndex(index)"
        >
          <div class="state-item-content">
            <ha-icon
              :icon="index === currentIndex ? 'mdi:checkbox-marked-circle' : 'mdi:checkbox-blank-circle-outline'"
              :class="{ 'active': index === currentIndex }"
            />
            <span class="state-name">{{ getEntityFriendlyName(entityId) }}</span>
            <span class="state-id">{{ entityId }}</span>
          </div>
        </div>
      </div>

      <!-- Settings info -->
      <div class="section settings-info">
        <div class="info-item">
          <ha-icon icon="mdi:power-cycle" />
          <span>Include off state: {{ includeOffState ? 'Yes' : 'No' }}</span>
        </div>
        <div v-if="timerInterval" class="info-item">
          <ha-icon icon="mdi:timer" />
          <span>Timer: {{ timerInterval }}s</span>
        </div>
      </div>
    </div>
  </ha-card>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import type {
  CardConfig,
  HomeAssistant,
  HassEntity,
} from './types';

// Props
const props = defineProps<{
  hass: HomeAssistant | null;
  config: CardConfig;
}>();

// Emit for config changes
const emit = defineEmits<{
  'config-changed': [config: CardConfig];
}>();

// State
const editMode = ref(false);
const configStates = ref<string[]>([]);
const configIncludeOffState = ref(false);
const configTimerInterval = ref<number | null>(null);
const configName = ref('State Cycler');
const newEntityId = ref('');

// Lifecycle
onMounted(() => {
  loadConfigFromEntity();
});

// Watch for entity changes
watch(() => props.config.entity, () => {
  loadConfigFromEntity();
});

// Load configuration from the entity
function loadConfigFromEntity() {
  if (!props.config.entity || !props.hass) return;
  const entity = getEntityState(props.config.entity);
  if (entity && entity.attributes) {
    configName.value = entity.attributes.friendly_name || 'State Cycler';
    configStates.value = Array.isArray(entity.attributes.states)
      ? [...entity.attributes.states]
      : [];
    configIncludeOffState.value = !!entity.attributes.include_off_state;
    configTimerInterval.value = entity.attributes.timer_interval ?? null;
  }
}

// Computed values for display
const cardTitle = computed(() => configName.value);
const entityState = computed(() => {
  if (!props.config.entity || !props.hass) return null;
  return props.hass.states[props.config.entity] || null;
});
const currentStateFriendly = computed(() => {
  return entityState.value?.attributes?.state_friendly || 'Off';
});
const currentIndex = computed(() => {
  return entityState.value?.attributes?.index ?? -1;
});
const toggleState = computed(() => {
  return entityState.value?.attributes?.toggle_state || false;
});
const states = computed(() => {
  return entityState.value?.attributes?.states || [];
});
const includeOffState = computed(() => {
  return entityState.value?.attributes?.include_off_state || false;
});
const timerInterval = computed(() => {
  return entityState.value?.attributes?.timer_interval || null;
});

// Helper to get entity state
const getEntityState = (entityId: string): HassEntity | null => {
  if (!props.hass || !props.hass.states) return null;
  return props.hass.states[entityId] || null;
};

// Get friendly name for an entity
const getEntityFriendlyName = (entityId: string): string => {
  const entity = getEntityState(entityId);
  return entity?.attributes?.friendly_name || entityId;
};

// Helper to call service
async function callService(service: string, data: any = {}) {
  if (!props.hass || !props.config.entity) return;
  await props.hass.callService('state_cycler', service, {
    entity_id: props.config.entity,
    ...data,
  });
}

// Service actions
async function handleToggle() {
  await callService('switch');
}
async function handleNext() {
  await callService('next');
}
async function handleCycle() {
  await callService('cycle');
}
async function handleToIndex(index: number) {
  await callService('to', { index });
}

// Config editing
function toggleEditMode() {
  if (editMode.value) {
    // Save changes
    saveConfig();
  } else {
    // Load current config
    loadConfigFromEntity();
  }
  editMode.value = !editMode.value;
}
function addEntity() {
  if (newEntityId.value && !configStates.value.includes(newEntityId.value)) {
    configStates.value.push(newEntityId.value);
    newEntityId.value = '';
  }
}
function removeEntity(index: number) {
  configStates.value.splice(index, 1);
}
function moveEntityUp(index: number) {
  if (index > 0) {
    const temp = configStates.value[index];
    configStates.value[index] = configStates.value[index - 1];
    configStates.value[index - 1] = temp;
  }
}
function moveEntityDown(index: number) {
  if (index < configStates.value.length - 1) {
    const temp = configStates.value[index];
    configStates.value[index] = configStates.value[index + 1];
    configStates.value[index + 1] = temp;
  }
}
async function saveConfig() {
  if (!props.hass || !props.config.entity) return;
  // TODO: Implement actual config save via Home Assistant API
  // For now, just log
  console.log('Saving config:', {
    states: configStates.value,
    include_off_state: configIncludeOffState.value,
    timer_interval: configTimerInterval.value,
  });
}
</script>

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

.warning {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  background: var(--error-color);
  color: white;
  border-radius: 8px;
}

.warning ha-icon {
  --mdc-icon-size: 24px;
}

/* Current state display */
.current-state {
  background: var(--card-background-color);
  border: 2px solid var(--divider-color);
  border-radius: 12px;
  padding: 16px;
}

.state-info {
  text-align: center;
}

.state-label {
  font-size: 14px;
  color: var(--secondary-text-color);
  margin-bottom: 8px;
}

.state-value {
  font-size: 24px;
  font-weight: 500;
  margin-bottom: 4px;
}

.state-index {
  font-size: 12px;
  color: var(--secondary-text-color);
}

/* Control buttons */
.controls {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.control-button {
  flex: 1;
  min-width: 100px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px 16px;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.toggle-button.on {
  background: var(--primary-color);
  color: white;
}

/* States list */
.states-list {
  max-height: 300px;
  overflow-y: auto;
}

.state-item {
  padding: 12px;
  margin-bottom: 8px;
  background: var(--card-background-color);
  border: 1px solid var(--divider-color);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.state-item:hover {
  border-color: var(--primary-color);
}

.state-item.active {
  background: var(--primary-color);
  color: white;
  border-color: var(--primary-color);
}

.state-item-content {
  display: flex;
  align-items: center;
  gap: 12px;
}

.state-name {
  font-weight: 500;
  flex: 1;
}

.state-id {
  font-size: 12px;
  color: var(--secondary-text-color);
}

.state-item.active .state-id {
  color: rgba(255, 255, 255, 0.7);
}

ha-icon.active {
  color: white;
}

/* Settings info */
.settings-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.info-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: var(--secondary-text-color);
}

/* Edit mode styles */
.edit-mode .entity-list {
  max-height: 400px;
  overflow-y: auto;
}

.entity-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  margin-bottom: 8px;
  background: var(--card-background-color);
  border: 1px solid var(--divider-color);
  border-radius: 8px;
}

.entity-name {
  font-weight: 500;
  flex: 1;
}

.entity-id {
  font-size: 12px;
  margin-right: auto;
}

.entity-actions {
  display: flex;
  gap: 4px;
}

.add-entity {
  display: flex;
  gap: 12px;
  margin-top: 12px;
}

.entity-input {
  flex: 1;
  padding: 8px 12px;
  border: 1px solid var(--divider-color);
  border-radius: 4px;
  background: var(--card-background-color);
  color: var(--primary-text-color);
  font-family: inherit;
  font-size: 14px;
}

.entity-input:focus {
  outline: none;
  border-color: var(--primary-color);
}

.option {
  margin-bottom: 12px;
}

.option label {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--primary-text-color);
}

.option input[type="checkbox"] {
  width: 18px;
  height: 18px;
}

.timer-input {
  margin-left: 8px;
  padding: 4px 8px;
  border: 1px solid var(--divider-color);
  border-radius: 4px;
  background: var(--card-background-color);
  color: var(--primary-text-color);
  width: 100px;
}

.timer-input:focus {
  outline: none;
  border-color: var(--primary-color);
}

.edit-button {
  color: var(--primary-color);
}
</style>
