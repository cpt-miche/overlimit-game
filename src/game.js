const canvas = document.getElementById('world');
const ctx = canvas.getContext('2d');
const worldHint = document.getElementById('worldHint');
const battleStatus = document.getElementById('battleStatus');
const primaryIndicator = document.getElementById('primaryIndicator');
const secondaryIndicator = document.getElementById('secondaryIndicator');
const statsGrid = document.getElementById('statsGrid');
const controls = document.getElementById('controls');
const actionsEl = document.getElementById('actions');
const abilitySelect = document.getElementById('abilitySelect');
const abilityUse = document.getElementById('abilityUse');
const ultimateSelect = document.getElementById('ultimateSelect');
const ultimateUse = document.getElementById('ultimateUse');
const endTurnButton = document.getElementById('endTurn');
const combatLog = document.getElementById('combatLog');
const kiInfusion = document.getElementById('kiInfusion');
const kiInfusionLabel = document.getElementById('kiInfusionLabel');
const escapeMenu = document.getElementById('escapeMenu');
const escapeTabs = Array.from(document.querySelectorAll('.escape-tab'));
const escapePanels = Array.from(document.querySelectorAll('.escape-panel'));
const skillList = document.getElementById('skillList');

const keys = new Set();
let mode = 'explore';

const playerWorld = { x: 140, y: 270, w: 34, h: 64, speed: 4 };

const enemyRoster = [
  {
    name: 'Martial Artist',
    tag: 'MARTIAL',
    maxHp: 320,
    hp: 320,
    maxStamina: 220,
    stamina: 220,
    maxStoredKi: 0,
    storedKi: 0,
    maxDrawnKi: 0,
    drawnKi: 0,
    physical: 38,
    ki: 0,
    speed: 34,
    canUseKi: false,
    canKaioken: false,
    strengthLabel: 'Very Weak'
  },
  {
    name: 'Saibaman',
    tag: 'SAIBAMAN',
    maxHp: 390,
    hp: 390,
    maxStamina: 230,
    stamina: 230,
    maxStoredKi: 160,
    storedKi: 160,
    maxDrawnKi: 140,
    drawnKi: 70,
    physical: 48,
    ki: 36,
    speed: 39,
    canUseKi: true,
    canKaioken: false,
    strengthLabel: 'Weak'
  },
  {
    name: 'Raditz (Scout)',
    tag: 'RADITZ',
    maxHp: 450,
    hp: 450,
    maxStamina: 240,
    stamina: 240,
    maxStoredKi: 360,
    storedKi: 360,
    maxDrawnKi: 240,
    drawnKi: 90,
    physical: 52,
    ki: 48,
    speed: 40,
    canUseKi: true,
    canKaioken: false,
    strengthLabel: 'Medium'
  },
  {
    name: 'Freiza',
    tag: 'FREIZA',
    maxHp: 740,
    hp: 740,
    maxStamina: 360,
    stamina: 360,
    maxStoredKi: 620,
    storedKi: 620,
    maxDrawnKi: 420,
    drawnKi: 220,
    physical: 86,
    ki: 94,
    speed: 76,
    canUseKi: true,
    canKaioken: false,
    strengthLabel: 'Very Strong'
  }
];

const enemyWorlds = enemyRoster.map((enemy, index) => ({
  ...enemy,
  x: 460 + index * 110,
  y: 270,
  w: 34,
  h: 64
}));

const baseActions = [
  { key: 'strike', label: 'Physical Strike', type: 'primary' },
  { key: 'kiBlast', label: 'Ki Blast', type: 'primary' },
  { key: 'powerUp', label: 'Power Up (+Drawn Ki)', type: 'secondary' },
  { key: 'guard', label: 'Guard', type: 'secondary' },
  { key: 'skipSecondary', label: 'Skip Secondary Action', type: 'secondary' }
];

const abilityActions = [
  { key: 'volley', label: 'Ki Volley' },
  { key: 'transform', label: 'Transform (SS1)' }
];

const protagonistSkills = [
  { name: 'Physical Strike', attack: 28, staminaCost: 18, kiCost: 0 },
  { name: 'Ki Blast', attack: 24, staminaCost: 4, kiCost: 22 },
  { name: 'Ki Blast Volley', attack: 34, staminaCost: 8, kiCost: 44 },
  { name: 'Ki Blast Barrage', attack: 50, staminaCost: 12, kiCost: 70 },
  { name: 'Transform (SS1)', attack: 'Form Buff', staminaCost: '5% max', kiCost: '2% stored' }
];

let activeEscapeTab = 'inventory';

function renderSkillList() {
  skillList.innerHTML = '';
  protagonistSkills.forEach((skill) => {
    const item = document.createElement('li');
    item.innerHTML = `<strong>${skill.name}</strong><span class="skill-item__meta">Attack: ${skill.attack} | Stamina Cost: ${skill.staminaCost} | Ki Cost: ${skill.kiCost}</span>`;
    skillList.appendChild(item);
  });
}

function setEscapeTab(tabName, shouldFocus = false) {
  activeEscapeTab = tabName;
  escapeTabs.forEach((tab) => {
    const isActive = tab.dataset.tab === tabName;
    tab.classList.toggle('is-active', isActive);
    tab.setAttribute('aria-selected', String(isActive));
    tab.setAttribute('tabindex', isActive ? '0' : '-1');
    if (isActive && shouldFocus) tab.focus();
  });

  escapePanels.forEach((panel) => {
    panel.classList.toggle('hidden', panel.id !== `panel${tabName[0].toUpperCase()}${tabName.slice(1)}`);
  });
}

function setEscapeMenuOpen(open) {
  escapeMenu.classList.toggle('hidden', !open);
  escapeMenu.setAttribute('aria-hidden', String(!open));
  if (open) {
    setEscapeTab(activeEscapeTab, true);
  }
}

function handleEscapeTabArrows(event) {
  const index = escapeTabs.findIndex((tab) => tab.dataset.tab === activeEscapeTab);
  if (index < 0) return;
  let nextIndex = index;
  if (event.key === 'ArrowRight') nextIndex = (index + 1) % escapeTabs.length;
  if (event.key === 'ArrowLeft') nextIndex = (index - 1 + escapeTabs.length) % escapeTabs.length;
  if (nextIndex !== index) {
    event.preventDefault();
    setEscapeTab(escapeTabs[nextIndex].dataset.tab, true);
  }
}

const ultimateActions = [
  { key: 'barrage', label: 'Ki Barrage' }
];

function makeFighter(name, isPlayer = false) {
  return {
    name,
    isPlayer,
    maxHp: 450,
    hp: 450,
    maxStamina: 240,
    stamina: 240,
    maxStoredKi: 360,
    storedKi: 360,
    maxDrawnKi: 240,
    drawnKi: 80,
    physical: 56,
    ki: 50,
    speed: 46,
    escalation: 0,
    guard: false,
    kaioken: false,
    formLevel: 0,
    roundDrain: { hp: 0, stamina: 0, drawnKi: 0 }
  };
}

let battle;

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function addLog(text) {
  const li = document.createElement('li');
  li.textContent = text;
  combatLog.prepend(li);
}

function updateActionIndicators() {
  if (!battle) {
    primaryIndicator.classList.remove('is-used');
    secondaryIndicator.classList.remove('is-used');
    return;
  }

  const turnState = battle.playerTurnState;
  primaryIndicator.classList.toggle('is-used', turnState.usedPrimary);
  secondaryIndicator.classList.toggle('is-used', turnState.usedSecondary);
}

function setupActionButtons() {
  actionsEl.innerHTML = '';
  baseActions.forEach((action) => {
    const button = document.createElement('button');
    button.textContent = action.label;
    button.addEventListener('click', () => playerAction(action.key));
    actionsEl.appendChild(button);
  });

  abilitySelect.innerHTML = '';
  abilityActions.forEach((action) => {
    const option = document.createElement('option');
    option.value = action.key;
    option.textContent = action.label;
    abilitySelect.appendChild(option);
  });

  ultimateSelect.innerHTML = '';
  ultimateActions.forEach((action) => {
    const option = document.createElement('option');
    option.value = action.key;
    option.textContent = action.label;
    ultimateSelect.appendChild(option);
  });

  abilityUse.addEventListener('click', () => playerAction(abilitySelect.value));
  ultimateUse.addEventListener('click', () => playerAction(ultimateSelect.value));
  endTurnButton.addEventListener('click', endPlayerTurn);
}

function startBattle(enemyProfile) {
  mode = 'battle';
  battle = {
    player: makeFighter('Player', true),
    enemy: { ...makeFighter(enemyProfile.name), ...enemyProfile },
    turn: 1,
    suppressionBase: 35,
    winner: null,
    playerTurnState: { usedPrimary: false, usedSecondary: false }
  };
  controls.classList.remove('hidden');
  kiInfusion.value = '0';
  addLog(`Encountered ${enemyProfile.name} (${enemyProfile.strengthLabel}). Fight starts cautiously.`);
  renderBattle();
}

function endBattle(win) {
  mode = 'explore';
  controls.classList.add('hidden');
  battle = null;
  updateActionIndicators();
  battleStatus.textContent = win
    ? 'Victory! You grew stronger. Walk around to challenge again.'
    : 'Defeat! Recover and challenge again.';
}

function getSuppression(fighter) {
  return clamp((battle.suppressionBase - fighter.escalation) / 100, 0, 0.5);
}

function mitigation(defender, type) {
  const sPct = defender.stamina / defender.maxStamina;
  const kPct = defender.drawnKi / defender.maxDrawnKi;
  const mix = type === 'physical' ? (0.65 * sPct + 0.35 * kPct) : (0.65 * kPct + 0.35 * sPct);
  return clamp(0.1 + mix * 0.55 + (defender.guard ? 0.2 : 0), 0.08, 0.88);
}

function tryVanish(attacker, defender, attackTier) {
  const vanishCost = 12 + attackTier * 8;
  if (defender.drawnKi < vanishCost) return false;
  const speedEdge = defender.speed - attacker.speed;
  const fatiguePenalty = defender.stamina / defender.maxStamina < 0.2 ? 0.15 : 0;
  const trackingBonus = attackTier * 0.08;
  const chance = clamp(0.2 + speedEdge * 0.008 - trackingBonus - fatiguePenalty, 0.05, 0.7);
  if (Math.random() < chance) {
    defender.drawnKi -= vanishCost;
    addLog(`${defender.name} vanished! (-${vanishCost} drawn ki)`);
    if (defender.stamina > 15 && defender.drawnKi > 10 && Math.random() < 0.45) {
      defender.stamina -= 12;
      defender.drawnKi -= 10;
      const counter = 16 + defender.physical * 0.5;
      attacker.hp -= counter;
      addLog(`${defender.name} countered for ${Math.round(counter)} damage!`);
    }
    return true;
  }
  return false;
}

function applyAttack(attacker, defender, cfg) {
  const requestedInfusionPct = Number(kiInfusion.value);
  const infusionPct = requestedInfusionPct / 100;
  const infusionCap = cfg.infusionCap ?? 0;
  const infusionCost = Math.round(attacker.maxDrawnKi * infusionPct * infusionCap);
  const kiCost = cfg.kiCost ?? 0;
  const staminaCost = cfg.staminaCost ?? 0;

  if (attacker.stamina < staminaCost || attacker.drawnKi < kiCost + infusionCost) {
    if (attacker.drawnKi < kiCost + infusionCost && requestedInfusionPct > 0 && infusionCap > 0) {
      const availableInfusionKi = Math.max(0, attacker.drawnKi - kiCost);
      let maxInfusionPct = 0;
      for (let pct = 0; pct <= 100; pct += 1) {
        const pctCost = Math.round(attacker.maxDrawnKi * (pct / 100) * infusionCap);
        if (pctCost <= availableInfusionKi) maxInfusionPct = pct;
      }
      addLog(`Not enough ki to attack with ${cfg.label} with ${requestedInfusionPct}% of ki infusion. (Max ${maxInfusionPct}%).`);
      return false;
    }
    addLog(`${attacker.name} tried ${cfg.label}, but lacked resources.`);
    return false;
  }

  attacker.stamina -= staminaCost;
  attacker.drawnKi -= kiCost + infusionCost;

  const speedBoost = attacker.kaioken ? 2 : 1;
  const boostedSpeed = attacker.speed * speedBoost;
  const hitChance = clamp(
    cfg.baseHit + (boostedSpeed - defender.speed) * 0.006 + infusionPct * 0.08 - (defender.guard ? 0.14 : 0),
    0.1,
    0.95
  );

  if (Math.random() > hitChance) {
    addLog(`${attacker.name}'s ${cfg.label} missed.`);
    return true;
  }

  if (cfg.canVanish && tryVanish(attacker, defender, cfg.tier)) return true;

  const suppression = 1 - getSuppression(attacker);
  const transBoost = attacker.kaioken ? 2 : 1;
  const statPower = cfg.type === 'physical' ? attacker.physical : attacker.ki;
  const infusionBoost = 1 + infusionPct * 0.9;
  const raw = (cfg.base + statPower * cfg.scaling) * suppression * transBoost * infusionBoost;
  const finalDmg = Math.max(1, Math.round(raw * (1 - mitigation(defender, cfg.type))));
  defender.hp -= finalDmg;
  attacker.escalation += cfg.escalationGain;
  defender.escalation += 2;
  addLog(`${attacker.name} used ${cfg.label} for ${finalDmg} damage.`);
  return true;
}

function applyRoundDrain(fighter) {
  if (!fighter.kaioken) return;
  const hpUpkeep = Math.round(fighter.maxHp * 0.01);
  const staminaUpkeep = Math.round(fighter.maxStamina * 0.06);
  fighter.hp -= hpUpkeep;
  fighter.stamina -= staminaUpkeep;
  addLog(`${fighter.name}'s Kaioken upkeep: -${hpUpkeep} HP, -${staminaUpkeep} stamina.`);
}

function consumeAction(type) {
  const turnState = battle.playerTurnState;
  if (type === 'ultimate') {
    if (turnState.usedPrimary || turnState.usedSecondary) {
      addLog('Ultimate attacks require both a fresh primary and secondary action.');
      return false;
    }
    turnState.usedPrimary = true;
    turnState.usedSecondary = true;
    return true;
  }

  if (type === 'primary') {
    if (turnState.usedPrimary) {
      addLog('Primary action already used this turn.');
      return false;
    }
    turnState.usedPrimary = true;
    return true;
  }

  if (turnState.usedSecondary) {
    addLog('Secondary action already used this turn.');
    return false;
  }
  turnState.usedSecondary = true;
  return true;
}

function maybeAutoEndTurn() {
  const turnState = battle.playerTurnState;
  if (turnState.usedPrimary && turnState.usedSecondary && !battle.winner) {
    endPlayerTurn();
  } else {
    renderBattle();
  }
}

function endPlayerTurn() {
  if (mode !== 'battle' || battle.winner) return;
  const turnState = battle.playerTurnState;
  if (!turnState.usedPrimary && !turnState.usedSecondary) {
    addLog('Use at least one action before ending the turn.');
    renderBattle();
    return;
  }

  if (checkWinner()) return;
  enemyTurn();
  if (checkWinner()) return;

  battle.player.guard = false;
  battle.turn += 1;
  battle.player.escalation += 3;
  battle.enemy.escalation += 3;
  applyRoundDrain(battle.player);
  applyRoundDrain(battle.enemy);
  battle.player.stamina = clamp(battle.player.stamina + 10, 0, battle.player.maxStamina);
  battle.enemy.stamina = clamp(battle.enemy.stamina + 10, 0, battle.enemy.maxStamina);
  battle.playerTurnState.usedPrimary = false;
  battle.playerTurnState.usedSecondary = false;
  renderBattle();
}

function playerAction(actionKey) {
  if (mode !== 'battle' || battle.winner) return;
  const p = battle.player;
  const e = battle.enemy;
  let executed = false;
  let actionType = 'primary';

  if (actionKey === 'powerUp' || actionKey === 'guard' || actionKey === 'skipSecondary') actionType = 'secondary';
  if (actionKey === 'barrage') actionType = 'ultimate';

  if (!consumeAction(actionType)) {
    renderBattle();
    return;
  }

  if (actionType === 'secondary') p.guard = false;

  switch (actionKey) {
    case 'strike':
      executed = applyAttack(p, e, {
        label: 'Physical Strike', type: 'physical', base: 28, scaling: 1.15,
        baseHit: 0.78, staminaCost: 18, kiCost: 0, infusionCap: 0.2,
        canVanish: true, tier: 1, escalationGain: 7
      });
      break;
    case 'kiBlast':
      executed = applyAttack(p, e, {
        label: 'Ki Blast', type: 'ki', base: 24, scaling: 1.05,
        baseHit: 0.75, staminaCost: 4, kiCost: 22, infusionCap: 0.32,
        canVanish: true, tier: 1, escalationGain: 8
      });
      break;
    case 'volley':
      executed = applyAttack(p, e, {
        label: 'Ki Volley', type: 'ki', base: 34, scaling: 1.08,
        baseHit: 0.85, staminaCost: 8, kiCost: 44, infusionCap: 0.4,
        canVanish: true, tier: 2, escalationGain: 10
      });
      break;
    case 'barrage':
      executed = applyAttack(p, e, {
        label: 'Ki Barrage', type: 'ki', base: 50, scaling: 0.95,
        baseHit: 0.92, staminaCost: 12, kiCost: 70, infusionCap: 0.55,
        canVanish: true, tier: 3, escalationGain: 13
      });
      break;
    case 'powerUp': {
      const amount = Math.min(45, p.storedKi, p.maxDrawnKi - p.drawnKi);
      if (amount <= 0) {
        addLog('No stored ki available to draw.');
      } else {
        p.storedKi -= amount;
        p.drawnKi += amount;
        p.escalation += 5;
        addLog(`Power up: converted ${amount} stored ki into drawn ki.`);
        executed = true;
      }
      break;
    }
    case 'guard':
      p.guard = true;
      p.stamina = clamp(p.stamina + 8, 0, p.maxStamina);
      addLog('Player braces and guards.');
      executed = true;
      break;
    case 'skipSecondary':
      addLog('Player skips their secondary action.');
      executed = true;
      break;
    case 'transform':
      if (p.formLevel >= 1) {
        addLog(`${p.name} is already at maximum form for this build.`);
      } else {
        const requiredStamina = Math.ceil(p.maxStamina * 0.05);
        const requiredStoredKi = Math.ceil(p.maxStoredKi * 0.02);
        if (p.stamina < requiredStamina || p.storedKi < requiredStoredKi) {
          addLog(`SS1 requires at least ${requiredStamina} stamina and ${requiredStoredKi} stored ki.`);
          break;
        }
        const prevMaxStamina = p.maxStamina;
        const prevStamina = p.stamina;
        p.formLevel = 1;
        p.physical = Math.round(p.physical * 5);
        p.ki = Math.round(p.ki * 5);
        p.speed = Math.round(p.speed * 2);
        p.maxStamina = Math.round(p.maxStamina * 2);
        const staminaMult = p.maxStamina / Math.max(1, prevMaxStamina);
        p.stamina = clamp(Math.round(prevStamina * staminaMult), 0, p.maxStamina);
        addLog(`${p.name} transforms to SS1! Stamina ${prevStamina}/${prevMaxStamina} -> ${p.stamina}/${p.maxStamina}.`);
        executed = true;
      }
      break;
  }

  if (!executed) {
    if (actionType === 'ultimate') {
      battle.playerTurnState.usedPrimary = false;
      battle.playerTurnState.usedSecondary = false;
    } else if (actionType === 'primary') {
      battle.playerTurnState.usedPrimary = false;
    } else {
      battle.playerTurnState.usedSecondary = false;
    }
  }

  if (checkWinner()) return;
  maybeAutoEndTurn();
}

function enemyTurn() {
  const p = battle.player;
  const e = battle.enemy;
  e.guard = false;

  const lowKi = e.drawnKi < 30;
  const lowStam = e.stamina < 25;

  if (e.canUseKi && lowKi && e.storedKi > 20 && Math.random() < 0.8) {
    const gain = Math.min(40, e.storedKi, e.maxDrawnKi - e.drawnKi);
    e.storedKi -= gain;
    e.drawnKi += gain;
    addLog(`${e.name} powers up (+${gain} drawn ki).`);
    return;
  }

  if (!e.name.startsWith('Raditz') && e.formLevel < 1 && Math.random() < 0.35) {
    const requiredStamina = Math.ceil(e.maxStamina * 0.05);
    const requiredStoredKi = Math.ceil(e.maxStoredKi * 0.02);
    if (e.stamina >= requiredStamina && e.storedKi >= requiredStoredKi) {
      const prevMaxStamina = e.maxStamina;
      const prevStamina = e.stamina;
      e.formLevel = 1;
      e.physical = Math.round(e.physical * 5);
      e.ki = Math.round(e.ki * 5);
      e.speed = Math.round(e.speed * 2);
      e.maxStamina = Math.round(e.maxStamina * 2);
      const staminaMult = e.maxStamina / Math.max(1, prevMaxStamina);
      e.stamina = clamp(Math.round(prevStamina * staminaMult), 0, e.maxStamina);
      addLog(`${e.name} transforms to ${e.tag === 'FREIZA' ? 'Frieza Second Form' : 'SS1'}!`);
      return;
    }
  }

  if (lowStam && Math.random() < 0.5) {
    e.guard = true;
    addLog(`${e.name} guards and regains footing.`);
    return;
  }

  if (e.tag === 'RADITZ' && e.drawnKi >= 68 && e.stamina >= 10 && Math.random() < 0.45) {
    applyAttack(e, p, {
      label: 'Double Sunday', type: 'ki', base: 62, scaling: 1.2,
      baseHit: 0.8, staminaCost: 10, kiCost: 68, infusionCap: 0.45,
      canVanish: true, tier: 2, escalationGain: 12
    });
    return;
  }

  const roll = Math.random();
  if (!e.canUseKi || e.maxDrawnKi === 0) {
    applyAttack(e, p, {
      label: 'Martial Rush', type: 'physical', base: 21, scaling: 0.95,
      baseHit: 0.79, staminaCost: 12, kiCost: 0, infusionCap: 0,
      canVanish: false, tier: 0, escalationGain: 4
    });
    return;
  }

  if (roll < 0.35) {
    applyAttack(e, p, {
      label: 'Wild Strike', type: 'physical', base: 25, scaling: 1.06,
      baseHit: 0.74, staminaCost: 16, kiCost: 0, infusionCap: 0.2,
      canVanish: true, tier: 1, escalationGain: 6
    });
  } else if (roll < 0.72) {
    applyAttack(e, p, {
      label: 'Ki Blast', type: 'ki', base: 22, scaling: 1.03,
      baseHit: 0.76, staminaCost: 4, kiCost: 20, infusionCap: 0.22,
      canVanish: true, tier: 1, escalationGain: 7
    });
  } else {
    applyAttack(e, p, {
      label: 'Ki Volley', type: 'ki', base: 32, scaling: 1.01,
      baseHit: 0.85, staminaCost: 8, kiCost: 40, infusionCap: 0.28,
      canVanish: true, tier: 2, escalationGain: 9
    });
  }
}

function checkWinner() {
  const p = battle.player;
  const e = battle.enemy;
  if (p.hp <= 0 || e.hp <= 0) {
    battle.winner = p.hp > 0 ? 'player' : 'enemy';
    addLog(battle.winner === 'player' ? 'You win!' : `${e.name} wins!`);
    renderBattle();
    endBattle(battle.winner === 'player');
    return true;
  }
  return false;
}

function renderFighter(f) {
  const suppressionPct = Math.round(getSuppression(f) * 100);
  const fatiguePhys = f.stamina / f.maxStamina < 0.2 ? 'LOW STAMINA: physical debuff' : '';
  const fatigueKi = f.drawnKi / f.maxDrawnKi < 0.2 ? 'LOW DRAWN KI: ki/vanish debuff' : '';

  return `
  <div class="card">
    <strong>${f.name} ${f.formLevel > 0 ? `(Form ${f.formLevel})` : ''} ${f.kaioken ? '(Kaioken)' : ''}</strong>
    ${renderBar('HP', f.hp, f.maxHp)}
    ${renderBar('Stam', f.stamina, f.maxStamina)}
    ${renderBar('Stored Ki', f.storedKi, f.maxStoredKi)}
    ${renderBar('Drawn Ki', f.drawnKi, f.maxDrawnKi)}
    <div>STR ${f.physical} | KI ${f.ki} | SPD ${f.speed}</div>
    <div>Escalation: ${Math.round(f.escalation)} | Hold-back Penalty: -${suppressionPct}%</div>
    <div style="color:#ffd58a">${fatiguePhys} ${fatigueKi}</div>
  </div>`;
}

function renderBar(label, value, max) {
  const pct = clamp((value / max) * 100, 0, 100);
  return `<div class="stat"><span>${label}</span><div class="bar"><div class="fill" style="width:${pct}%"></div></div><span>${Math.max(0, Math.round(value))}/${max}</span></div>`;
}

function renderBattle() {
  if (!battle) return;
  statsGrid.innerHTML = `${renderFighter(battle.player)}${renderFighter(battle.enemy)}`;
  const turnState = battle.playerTurnState;
  const primaryLeft = turnState.usedPrimary ? 'used' : 'ready';
  const secondaryLeft = turnState.usedSecondary ? 'used' : 'ready';
  battleStatus.textContent = `Turn ${battle.turn}. Primary: ${primaryLeft}. Secondary: ${secondaryLeft}. End turn after acting.`;
  updateActionIndicators();
}

function drawWorld() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
  gradient.addColorStop(0, '#25365f');
  gradient.addColorStop(1, '#101726');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.fillStyle = '#2f6d3b';
  ctx.fillRect(0, 310, canvas.width, 50);

  drawCharacter(playerWorld, '#4db2ff', 'YOU');
  enemyWorlds.forEach((enemy) => drawCharacter(enemy, '#ff7e54', enemy.tag, enemy.name));

  if (mode === 'explore') {
    const nearbyEnemy = enemyWorlds.find((enemy) => Math.abs(playerWorld.x - enemy.x) < 55);
    worldHint.textContent = nearbyEnemy
      ? `Press E to challenge ${nearbyEnemy.name}.`
      : 'Move with A/D or ←/→.';
    if (nearbyEnemy && keys.has('e')) startBattle(nearbyEnemy);
  }
}

function drawCharacter(ch, color, label, name = '') {
  ctx.fillStyle = color;
  ctx.fillRect(ch.x - ch.w / 2, ch.y - ch.h, ch.w, ch.h);
  ctx.fillStyle = '#fff';
  ctx.font = '12px sans-serif';
  if (name) {
    ctx.fillText(name, ch.x - ch.w / 2 - 10, ch.y - ch.h - 22);
  }
  ctx.fillText(label, ch.x - ch.w / 2 - 4, ch.y - ch.h - 8);
}

function tick() {
  if (mode === 'explore') {
    if (keys.has('a') || keys.has('arrowleft')) playerWorld.x -= playerWorld.speed;
    if (keys.has('d') || keys.has('arrowright')) playerWorld.x += playerWorld.speed;
    playerWorld.x = clamp(playerWorld.x, 20, canvas.width - 20);
  }
  drawWorld();
  requestAnimationFrame(tick);
}

escapeTabs.forEach((tab) => {
  tab.addEventListener('click', () => setEscapeTab(tab.dataset.tab));
});

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    setEscapeMenuOpen(escapeMenu.classList.contains('hidden'));
    return;
  }

  if (!escapeMenu.classList.contains('hidden')) {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') handleEscapeTabArrows(event);
    return;
  }

  keys.add(event.key.toLowerCase());
});
window.addEventListener('keyup', (event) => keys.delete(event.key.toLowerCase()));
kiInfusion.addEventListener('input', () => {
  kiInfusionLabel.textContent = `${kiInfusion.value}%`;
});

renderSkillList();
setupActionButtons();
tick();
