Do something to make the deployment easier:
A single command which does:
- bump version (v0.0.0-pre11 -> v0.0.0-pre12)
- lint & format python & typescript
- build frontend (to test it builds)
- pushes to origin mane (including the tag)
Additionally:
- have a makefile with commands for the individual steps.
- The "Warning: You have uncommitted changes" should follow gitignore
- Sync the version numbers with the tags
- it should only increment the version after it succeeded with the tests.
- Add the GH release url and the hacs install url to `View the release at:` in the script.
- Add a `make commit` script, which:
  - first commits changes to `ai/query.md` with the message `ai: updated query`
  - secondly commits changes to `ai/errors.md` with `ai: updated errors`
  - third commit all other changes with `ai: running... ($step-$substep)` (where $substep will be reset to 1 in the script, and $step incremented compared to the last commit matching that.
- So the order will be:
  - first check for all errors except formating nitpicks
  - run commit.sh
  - run the python formatter
  - commit those changes with `lint: ruff`
  - run the ts formatter
  - commit these changes with `lint: ts`
  - build it to confirm it working
  - only now that every test was successful:
    - increase the versions
    - add the version-changed file(s) to git
    - commit a message with "version: bumped `x` -> `y`"  (a proper unicode arrow)
    - tag the commit.
    - and finally push the commit and the tag to origin mane.
- Do not use `git add --all`. I prefer only updated over all.
- Also if there's anything staged to git, remove that, and restore it afterwards (before/for the commit rest step)
- release depends on successful lint, build.

Regarding formatting:
- I don't want prettier to ever move multiline stuff back to single line if "it fits better"! That needs to be DISABLED, or a different tool be used!
- use airbnb style for ts etc.
- Unlimited line width, but prefer one-element-per line for arrays, html attributes, function params etc.
- make sure it formats Vue files, too.
- reminder that the config key is called `"markup": { …` not `"markup_fmt"`.

——————————

bash script get own file dir

——————————

```
🔍 Step 1: Check for lint errors
Running ruff check...
… ruff error output …
Found 1 error. [*] 1 fixable with the `--fix` option. make: *** [release] Error 1
```

Also insert a step where the linter has only fixable errors, so it commits the file before, then does an "autofix" commit afterwards - similar to the format ones.

The interesting part is, the first step already fails if it has those fixable issues - they are at that point still considered issues.

——————————

fatal: tag 'v0.0.0-pre19' already exists
Ask to move the tag (delete the old one and recreate as intended)

——————————

➜ make commit
Script directory: /Users/user/Documents/programming/Python/HomeAssistant/hoass_calendar-alarm-clock/scripts
📝 Calendar Alarm Clock - Commit Script

Saving staged changes...
Saved working directory and index state On mane: commit-script-staged-backup
error: removal patch leaves file contents
error: ai/debugging-auto-discovery.md: patch does not apply
Cannot remove worktree changes
make: *** [commit] Error 1

But using `git reset HEAD` sounds like it could delete stuff we still need?
——————————

in the scripts/ folder, write me a script which would replace this template with a homeassistant plugin name.
Ask for a plugin name (e.g. "Calendar Alarm Clock") as input.
This is for names displayed in the UI.

calculate a lowercase-dash version, (i.e. "calendar-alarm-clock") which would be the default, but again ask the user.
This is for custom component names and filenames (i.e. `<calendar-alarm-clock-card>`, `calendar-alarm-clock-card.js` and `calendar-alarm-clock-editor.css`)

Then also convert that to real snake_case ("calendar_alarm_clock"); again as default and the possibility to change it for the user.
This will be for module names on the python side, integration domain and sensor names, etc.

Using the dashed-lowercase, construct the github repo `https://github.com/luckydonald/hoass_calendar-alarm-clock.git`, to input in plenty of files.

Then ask if we need a python backend, if not, remove the related files.

After that, ask for a frontend choice, either `vue` or `plain`, for which either the `frontend_vue` or `frontend_plain` folder is kept, and renamed as `frontend`.

Finally, (but do not add that yet!): 
the script shall replace all `template`, `Template` etc. with the given strings.
For that it shall go through a hardcoded list of files and replace the relevant parts. (this is because `template` might be a too common word in homeassistant.)

—————

please - in my local files - rename "template" to "plugin_template" (in all the cases needed. Also rename calendar_alarm_clock to plugin_template and all the other caseings similarly in the files directly, and adapt the script for that, so it's uniformly something which is easier to recognize.

Please additionally also remove code which might have been specific to the one I compied from - I only want a good starting point, so remove everything alarm-clock or calendar specific.

———————

Set up tests for the frontend and backend, with a few example tests.

————————

In `scripts/init.sh`, make sure everything is properly replaced, including in the test files.

The script also should be save to re-run, even with a later version with updated files.
It should not fail, but just adapt new files as needed.
This is extra important for the folder copy/rename parts, we can't just overwrite existing folders.
Instead, if that folder already exists, ask for each non-existing file if it should be copied over and adapted or skipped.

———————

Add `make init`.

———————

In the `scripts/init.sh`:
- Try to deduct the name from the current folder name as default.
  - obviously, strip common prefixes like `ha_`, `hacs_`, `hoass_`, `homeassistant_` if existing.
- after asking for the plugin name etc., also ask for a github username (defaulting to "luckydonald"), and use that in the constructed github repo url.

———————

I want to make the `commit.sh` script intelligent for the commit message ai-run-number increase:
- Go back the commit messages, and if you find one matching `ai: running... ($step-$substep)`, use that to determine the current $substep. If you however first find a ai: updated query or ai: updated errors, reset the substep counter to 1, and increase the step counter by one instead.
- If no previous ai: running... commit is found, start with (1-1).

Additionally, detect if the commit script is run in the template repository (root dir name is `hoass_{plugin-,plugin_,}template/`.
If that is the case, the commit syntax is different:
Instead of `$COMMIT_MSG_STEP`, resulting in `ai: running... (7-2)`, use "📄TEMPLATE | ✨ ai: [007] Message here… (2/X)", from the following:
```shell
COMMIT_MSG_STEP="✨ ai: running... ({step}-{substep})"
COMMIT_MSG_STEP_TEMPLATE="${COMMIT_PREFIX_TEMPLATE}✨ ai: [{padded_step}] {msg} ({substep}-{total_substeps})"
```
Notice, the first part is `${COMMIT_PREFIX_TEMPLATE}`, the $step is now named $padded_step and zero-padded to three digits, and the substep is 2. The total_substeps will initially be "X", as it is currently unknown what the total number of substeps will be.
If the template repo is detected, the search for the previous substep as above must be adapted to the new syntax as well.
Keep in mind, that the message is not always "running...", but will later be changed with an rebase to something more useful. The detection must work with that. Also I use `…`, not three separate dots.

——————

Write me a `scripts/fix-commits.sh` (incl. `make fix-commits`), which will rebase the last set of `📄TEMPLATE | ✨ ai: [013] running… (2/X)` or `✨ ai: running… (2-X)`.
In the case with the total, it should replace the X on that correct position with the total for that batch (here 013), and for both formats also ask what to change the message to, if it's still the default the script put down.

——————

Make sure `init.sh` cleans up template-specific stuff, like the `ai/plugin_template/` dir or unused `frontend_*` folders.
