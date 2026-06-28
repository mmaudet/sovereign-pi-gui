import { existsSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// anthropics/skills is cloned by scripts/mirror-setup.sh to:
//   ~/.pi/agent/git/github.com/anthropics/skills/skills/<name>/SKILL.md
const SKILLS_ROOT = `${process.env.HOME}/.pi/agent/git/github.com/anthropics/skills/skills`;

const DEFAULT_ENABLED = [
    "frontend-design",
    "web-artifacts-builder",
    "webapp-testing",
    "theme-factory",
    "brand-guidelines",
    "canvas-design",
];

// Override the set with ORNITH_ANTHROPIC_SKILLS="a,b,c" if desired.
const ENABLED = process.env.ORNITH_ANTHROPIC_SKILLS
    ? process.env.ORNITH_ANTHROPIC_SKILLS.split(",").map((s) => s.trim()).filter(Boolean)
    : DEFAULT_ENABLED;

export default function anthropicSkillsPack(pi: ExtensionAPI) {
    // Point at each skill's SKILL.md file. The SDK's loadSkills() accepts either a directory
    // or a .md file; the file form loads exactly one skill with no directory-scan surprises.
    const skillPaths = ENABLED
        .map((name) => join(SKILLS_ROOT, name, "SKILL.md"))
        .filter((p) => existsSync(p));
    pi.on("resources_discover", () => ({ skillPaths }));
}
