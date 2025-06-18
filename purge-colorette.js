const fs = require('fs');
const path = require('path');

const libDir = 'c:/Development Apps/Cascades projects/vip_lounge_notification_bookings/node_modules/firebase-tools/lib';

const MOCK_DEFINITIONS = `
// Patched by Cascade to remove colorette dependency
const clc = new Proxy({}, { get: () => (str) => str });
const colorette_1 = new Proxy({}, { get: () => (str) => str });
`;

function walk(dir, callback) {
    const files = fs.readdirSync(dir);
    for (const f of files) {
        const dirPath = path.join(dir, f);
        try {
            const isDirectory = fs.statSync(dirPath).isDirectory();
            if (isDirectory) {
                walk(dirPath, callback);
            } else {
                callback(path.join(dir, f));
            }
        } catch (e) {
            console.error(`Could not stat path ${dirPath}, skipping.`);
        }
    }
}

console.log(`Starting colorette purge in ${libDir}`);
let filesProcessed = 0;
let filesPatched = 0;

walk(libDir, (filePath) => {
    if (path.extname(filePath) !== '.js') {
        return;
    }
    filesProcessed++;

    try {
        let content = fs.readFileSync(filePath, 'utf8');
        
        const usesColorette = /clc\.|colorette_1\.|\brequire\(['"]colorette['"]\)/.test(content);
        if (!usesColorette) {
            return;
        }

        // Remove any existing require('colorette') line, commented or not.
        let modifiedContent = content.replace(/^\s*(?:\/\/)?\s*const\s+.*\s*=\s*require\(['"]colorette['"]\);?\s*$/gm, '');

        // Inject mock definitions at the top, after "use strict"; if it exists.
        const useStrictRegex = /^\s*["']use strict["'];?/m;
        if (useStrictRegex.test(modifiedContent)) {
            modifiedContent = modifiedContent.replace(useStrictRegex, (match) => `${match}${MOCK_DEFINITIONS}`);
        } else {
            modifiedContent = MOCK_DEFINITIONS + '\n' + modifiedContent;
        }
        
        if (content !== modifiedContent) {
            console.log(`Patched: ${filePath}`);
            fs.writeFileSync(filePath, modifiedContent, 'utf8');
            filesPatched++;
        }

    } catch (err) {
        console.error(`Failed to process ${filePath}: ${err.message}`);
    }
});

console.log(`Purge complete. Processed ${filesProcessed} files, patched ${filesPatched} files.`);
