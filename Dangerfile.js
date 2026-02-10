// Dangerfile.js
const { danger, warn, fail } = require("danger");

// 1. Mandatory Documentation Check
const hasCodeChanges = danger.git.modified_files.some(f => f.startsWith("src-"));
const hasDocChanges = danger.git.modified_files.some(f => 
  f.startsWith(".specify/") || 
  f.endsWith(".md") || 
  f === "project.json"
);

if (hasCodeChanges && !hasDocChanges) {
  warn("Změnil jsi kód v 'src-', ale neaktualizoval jsi dokumentaci v '.specify/' nebo kořenové *.md soubory. Prosím, ověř integritu.");
}

// 2. Big PR Warning
const threshold = 500;
if (danger.github.pr.additions + danger.github.pr.deletions > threshold) {
  warn(`Tento Pull Request je příliš velký (> ${threshold} řádků). Zvaž rozdělení pro lepší kontrolu sémantiky.`);
}

// 3. TODO Check
const modifiedFiles = danger.git.modified_files.concat(danger.git.created_files);
modifiedFiles.forEach(file => {
  if (file.endsWith(".md") || file.endsWith(".js") || file.endsWith(".rs")) {
    const diff = danger.git.diffForFile(file);
    if (diff && diff.added.includes("TODO")) {
      warn(`Soubor ${file} obsahuje 'TODO' - nezapomeň to vyřešit před finálním releasem.`);
    }
  }
});
