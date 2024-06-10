const {Interface, FunctionFragment} = require("@ethersproject/abi");

function getSelectors(abi) {
    return abi.reduce((acc, fragment) => {
        if (fragment.type === 'function') {
            acc.push(Interface.getSighash(FunctionFragment.from(fragment)));
        }
        return acc;
    }, []);
}

function intersectionSet(a, b) {
    return a.filter(i => b.includes(i));
}

function differenceSet(a, b) {
    return a.filter(i => !b.includes(i));
}

function encodeDiamondCutCall(abi, params) {
    let diamondCutAbi = abi.filter(fragment => {
        return fragment.type === 'function' && fragment.name === 'diamondCut';
    });
    return new Interface(diamondCutAbi).encodeFunctionData(FunctionFragment.from(diamondCutAbi[0]), params);
}

function entriesAreEqual(entry1, entry2) {
    // if (!entry1 || !entry2) return false;
    if (entry1.type !== entry2.type) return false;
    if (entry1.name !== entry2.name) return false;
    if (!Array.isArray(entry1.inputs) || !Array.isArray(entry2.inputs)) return false;
    if (entry1.inputs.length !== entry2.inputs.length) return false;

    for (let i = 0; i < entry1.inputs.length; i++) {
        if (entry1.inputs[i] === undefined || entry2.inputs[i] === undefined) return false;
        if (
            entry1.inputs[i].hasOwnProperty('components') &&
            entry2.inputs[i].hasOwnProperty('components') &&
            !entriesAreEqual({inputs: entry1.inputs[i].components}, {inputs: entry2.inputs[i].components})
        ) {
            return false;
        }
    }
    return true;
}

function removeDuplicateAbiEntries(abi) {
    return abi.filter((entry, index, self) =>
        index === self.findIndex(existingEntry =>
            entriesAreEqual(entry, existingEntry)));
}

function mergeABIs(abi1, abi2) {
    const mergedABI = [];

    // Add all entries from the first ABI
    for (const entry of abi1) {
        mergedABI.push(entry);
    }

    // Add only unique entries from the second ABI
    for (const entry2 of abi2) {
        let isUnique = true;
        for (const entry1 of abi1) {
            if (entriesAreEqual(entry1, entry2)) {
                isUnique = false;
                break;
            }
        }
        if (isUnique) mergedABI.push(entry2);
    }
    return removeDuplicateAbiEntries(mergedABI);
}

exports.getSelectors = getSelectors;
exports.intersectionSet = intersectionSet;
exports.differenceSet = differenceSet;
exports.encodeDiamondCutCall = encodeDiamondCutCall;
exports.mergeABIs = mergeABIs;