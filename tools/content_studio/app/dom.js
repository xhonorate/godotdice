// The four helpers every panel in the studio is built out of.

export function el(tag, props = {}, children = []) {
	const node = document.createElement(tag);
	for (const [key, value] of Object.entries(props)) {
		if (key === "class") node.className = value;
		else if (key === "text") node.textContent = value;
		else if (key === "html") node.innerHTML = value;
		else if (key.startsWith("on")) node.addEventListener(key.slice(2).toLowerCase(), value);
		else if (value !== null && value !== undefined && value !== false) node.setAttribute(key, value === true ? "" : value);
	}
	for (const child of [].concat(children)) if (child) node.append(child);
	return node;
}

/** Replaces a node's children, dropping the empty slots a conditional child leaves behind.
 *  `replaceChildren(null)` would otherwise insert the text "null". */
export function mount(node, ...children) {
	node.replaceChildren(...children.flat().filter((child) => child !== null && child !== undefined && child !== false));
	return node;
}

export const $ = (selector) => document.querySelector(selector);
export const clamp = (value, low, high) => Math.min(high, Math.max(low, value));
export const titleCase = (text) => String(text).replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
