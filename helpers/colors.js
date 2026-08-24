
export const DEFAULT_THRESHOLD_RGBA = {
    red: 224 / 255,
    green: 27 / 255,
    blue: 36 / 255,
};

export function parseColorEntry(colorEntry) {
    if (typeof colorEntry !== 'string')
        return null;

    const parts = colorEntry.trim().split(' ');
    if (parts.length < 4)
        return null;

    const threshold = Number(parts[0]);
    const red = Number(parts[1]);
    const green = Number(parts[2]);
    const blue = Number(parts[3]);
    if (![threshold, red, green, blue].every(Number.isFinite))
        return null;

    let sensorKey = null;
    if (parts.length > 4) {
        const rest = parts.slice(4).join(' ');
        if (!rest.startsWith('sensor:') || rest.length <= 'sensor:'.length)
            return null;
        sensorKey = rest.slice('sensor:'.length);
        if (!sensorKey)
            return null;
    }

    return {threshold, red, green, blue, sensorKey};
}

export function formatColorEntry({threshold, red, green, blue, sensorKey = null}) {
    let entry = `${threshold} ${red} ${green} ${blue}`;
    if (sensorKey)
        entry += ` sensor:${sensorKey}`;
    return entry;
}

export function compareColorEntries(a, b) {
    if (a.threshold !== b.threshold)
        return a.threshold - b.threshold;
    let aKey = a.sensorKey || '';
    let bKey = b.sensorKey || '';
    return aKey < bKey ? -1 : aKey > bKey ? 1 : 0;
}

export function sanitizeAndSortColorEntries(colorsArray) {
    return (colorsArray || [])
        .map(parseColorEntry)
        .filter(Boolean)
        .sort(compareColorEntries);
}

function normalizeColorComponent(component) {
    if (!Number.isFinite(component))
        return null;

    const scaled = component > 1 ? component : component * 255;
    return Math.max(0, Math.min(255, Math.round(scaled)));
}

function styleForEntries(value, entries) {
    const thresholds = entries
        .slice()
        .sort((a, b) => a.threshold - b.threshold)
        .map(entry => {
            const red = normalizeColorComponent(entry.red);
            const green = normalizeColorComponent(entry.green);
            const blue = normalizeColorComponent(entry.blue);
            if (red === null || green === null || blue === null)
                return null;

            return {
                threshold: entry.threshold,
                style: `color: rgb(${red}, ${green}, ${blue});`,
            };
        })
        .filter(Boolean);

    if (thresholds.length === 0)
        return '';

    for (let index = thresholds.length - 1; index >= 0; index--) {
        if (value >= thresholds[index].threshold)
            return thresholds[index].style;
    }

    return '';
}

export function getUsageColor(value, colors, sensorKey = null) {
    if (!colors || colors.length === 0 || !Number.isFinite(value))
        return '';

    const entries = colors.map(parseColorEntry).filter(Boolean);
    if (entries.length === 0)
        return '';

    if (sensorKey) {
        const specific = entries.filter(entry => entry.sensorKey === sensorKey);
        if (specific.length > 0)
            return styleForEntries(value, specific);
    }

    const groupWide = entries.filter(entry => !entry.sensorKey);
    return styleForEntries(value, groupWide);
}

export function sensorKeyFromTypeLabel(type, label) {
    let typeKey = (type || '').replace('-group', '');
    if (/^network-(?!rx$|tx$)/.test(typeKey))
        typeKey = 'network';
    return '_' + typeKey + '_' + String(label).replace(' ', '_').toLowerCase() + '_';
}

export function parseSensorKey(key) {
    if (typeof key !== 'string' || !key.startsWith('_') || key.length < 3)
        return null;

    let inner = key.endsWith('_') ? key.slice(1, -1) : key.slice(1);
    let parts = inner.split('_');
    return {
        typePart: parts[0] || '',
        label: parts.slice(1).join(' ').trim(),
    };
}

export function labelFromSensorKey(key) {
    let parsed = parseSensorKey(key);
    if (!parsed)
        return key || '';

    let {typePart, label} = parsed;
    if (typePart.startsWith('gpu') && label)
        return `${label} (${typePart})`;
    return label || typePart;
}

export function sensorKeyBelongsToColorPage(pageName, key) {
    if (typeof key !== 'string' || !key.startsWith('_') || key.startsWith('__'))
        return false;

    let parsed = parseSensorKey(key);
    if (!parsed)
        return false;

    let {typePart} = parsed;

    if (pageName === 'temperature') {
        if (typePart === 'temperature')
            return true;
        return typePart.startsWith('gpu') && /temp/i.test(key);
    }

    if (pageName === 'gpu') {
        if (!typePart.startsWith('gpu'))
            return false;
        return !/temp/i.test(key);
    }

    return typePart === pageName || typePart.startsWith(pageName + '#');
}