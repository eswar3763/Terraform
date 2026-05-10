# Git & GitHub Interview Guide
## Complete Coverage of Merge, Rebase, Cherry-Pick, Branching Strategies, and Real-World Scenarios

**Last Updated**: May 2026  
**Version**: 1.0.0

---

## Table of Contents
1. [Git Fundamentals](#git-fundamentals)
2. [Merge vs Rebase](#merge-vs-rebase)
3. [Cherry-Pick Explained](#cherry-pick-explained)
4. [Branching Strategies](#branching-strategies)
5. [Finding Your Feature Branch Base Commit](#finding-your-feature-branch-base-commit)
6. [Interview Q&A](#interview-qa)
7. [Real-World Scenarios](#real-world-scenarios)
8. [Git Troubleshooting](#git-troubleshooting)

---

## Git Fundamentals

### Git Workflow Basics

```
Working Directory → Staging Area → Local Repository → Remote Repository
    (unstaged)      (staged)      (committed)      (pushed)
```

### Key Concepts

| Concept | Definition |
|---------|-----------|
| **Commit** | Snapshot of code at a point in time (includes parent reference) |
| **Branch** | Pointer to a commit (lightweight reference) |
| **HEAD** | Points to the current branch or commit |
| **Origin** | Default remote repository name |
| **Upstream** | The branch you're tracking (usually `origin/main`) |
| **Fast-Forward** | Merge when target branch has no new commits |
| **Merge Commit** | New commit created when merging non-FF branches |

### Git Object Graph

```
A (main)
├── B 
│   └── C (feature branch)
│       └── D
│           └── E (current HEAD)
│
└── F (staging branch)
    └── G
```

Every commit has:
- **SHA-1 hash** (commit ID): `abc123def456...`
- **Parent commit(s)**: Reference to previous commit(s)
- **Author**: Who wrote the code
- **Committer**: Who applied the commit
- **Message**: Commit description
- **Tree**: The actual file contents snapshot

---

## Merge vs Rebase

### Understanding the Difference

#### MERGE
Creates a **merge commit** combining two branches with a new commit that has **two parents**.

```
Before Merge:
main:       A -- B -- C (HEAD: main)
                 \
feature:          D -- E (HEAD: feature)

After Merge:
main:       A -- B -- C -- M (merge commit, HEAD: main)
                 \       /
feature:          D -- E

Git history shows: A → B → C → M
And from M: can trace back to both C and E
```

**Command**:
```bash
git checkout main
git merge feature
# Creates new commit M with parents C and E
```

**Advantages**:
- ✅ Preserves complete history
- ✅ Shows when and how branches merged
- ✅ Non-destructive
- ✅ Easy to understand branch history

**Disadvantages**:
- ❌ Creates "messy" commit history with merge commits
- ❌ Harder to read linear history with many merges
- ❌ Difficult to bisect (find problematic commit)

#### REBASE
Replays commits from one branch on top of another, **rewriting history**.

```
Before Rebase:
main:       A -- B -- C (HEAD: main)
                 \
feature:          D -- E (HEAD: feature)

After Rebase (feature onto main):
main:       A -- B -- C (HEAD: main)
                     \
feature:              D' -- E' (HEAD: feature)
                      (new commits with new SHAs)

Linear history: A → B → C → D' → E'
```

**Command**:
```bash
git checkout feature
git rebase main
# Replays D and E on top of C
# Creates new commits D' and E' with new SHAs

# To merge back without merge commit:
git checkout main
git merge feature --ff-only
# Fast-forwards main to E' (no merge commit)
```

**Advantages**:
- ✅ Clean, linear history
- ✅ Easier to read commit sequence
- ✅ Easier to bisect
- ✅ Professional-looking timeline

**Disadvantages**:
- ❌ Rewrites history (commits get new SHAs)
- ❌ Can be confusing for team members
- ❌ Should NOT rebase shared/public branches
- ❌ Loses merge context

### Practical Comparison

```
MERGE Decision Tree:
│
├─ Do you want to preserve complete history?
│  └─ YES → Use MERGE
│
└─ Do you want clean linear history?
   └─ YES → Use REBASE (on feature branches only)

Rule of Thumb:
- Use REBASE on: feature branches, local branches
- Use MERGE on: main, master, shared branches
```

### Interactive Rebase - Powerful History Rewriting

```bash
# Rebase last 5 commits interactively
git rebase -i HEAD~5

# Opens editor with:
# pick abc123 First commit
# pick def456 Second commit
# pick ghi789 Third commit
# ...

# Change 'pick' to:
# pick   - Keep commit as is
# reword - Keep but edit message
# squash - Combine with previous commit
# fixup  - Combine and discard message
# drop   - Remove commit entirely
# edit   - Pause and allow amendments
```

**Example: Squashing commits**
```bash
# Before: Have 3 commits with typos/fixes
pick abc123 Add login feature
pick def456 Fix typo in login
pick ghi789 Update tests

# Change to:
pick abc123 Add login feature
squash def456 Fix typo in login
squash ghi789 Update tests

# Result: Single commit "Add login feature" with all changes
```

---

## Cherry-Pick Explained

Cherry-pick applies a **specific commit** from one branch to another **without merging the entire branch**.

### Use Cases

1. **Apply bug fix to multiple branches**
   - Hot fix in main that needs to go to staging/dev

2. **Selective commit inclusion**
   - Want commit #5 but not commits #1-4

3. **Release management**
   - Pick specific features for a release

4. **Undo merges**
   - Applied merge by mistake, pick commits individually

### Cherry-Pick Workflow

```
main:       A -- B -- C -- D -- E
                 \
feature:          F -- G -- H

Want to apply G to main:

git checkout main
git cherry-pick F   # Pick G's parent first if needed
git cherry-pick G   # Now pick G
git cherry-pick H   # And H

Result:
main:       A -- B -- C -- D -- E -- F' -- G' -- H'
                 \
feature:          F -- G -- H

Note: F', G', H' have same changes but different SHAs
      (different parent commits)
```

### Syntax

```bash
# Single commit
git cherry-pick abc123

# Range of commits (exclusive of start)
git cherry-pick abc123..def456
# Includes commits from abc123+1 to def456

# Range inclusive
git cherry-pick abc123^..def456
# Includes abc123 to def456

# Multiple specific commits
git cherry-pick abc123 def456 ghi789

# With merge commit (if cherry-picked commit is a merge)
git cherry-pick -m 1 abc123

# Continue after conflict resolution
git cherry-pick --continue

# Abort cherry-pick
git cherry-pick --abort
```

### Cherry-Pick vs Merge vs Rebase

```
Scenario: Want to apply changes from feature branch to main

MERGE:
  git merge feature
  → All commits from feature apply
  → Creates merge commit
  → Preserves branch relationship

REBASE:
  git rebase feature
  → Replays main on top of feature
  → Rewrites history
  → Loses branch separation

CHERRY-PICK:
  git cherry-pick commit1 commit2
  → Apply only specific commits
  → Commits get new SHAs
  → Selective integration
```

---

## Branching Strategies

### Git Flow (Scheduled Releases)

```
main (production)
  ↑
  │ (merge --no-ff)
  │
release/1.0
  ↑
  │ (branch off develop)
  │
develop (staging/pre-release)
  ↑
  │ (merge --no-ff)
  │
feature/login (developer works here)
  │
feature/signup
  │
feature/payment
```

**Workflow**:
```bash
# Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/user-authentication

# Work on feature (multiple commits)
git commit -m "Add login endpoint"
git commit -m "Add password hashing"
git commit -m "Add JWT tokens"

# Push feature branch
git push origin feature/user-authentication

# Create Pull Request on GitHub
# After review and merge:
git checkout develop
git pull origin develop

# If using merge --no-ff to preserve branch info
git merge --no-ff feature/user-authentication
git push origin develop

# When ready for release:
git checkout -b release/1.0 develop
# Update version numbers
git commit -m "Bump version to 1.0.0"
git checkout main
git merge --no-ff release/1.0
git tag -a v1.0.0
git push origin main
git push --tags

# Delete release branch
git branch -d release/1.0

# Merge back to develop (in case of hotfixes)
git checkout develop
git merge --no-ff release/1.0

# If hotfix needed:
git checkout -b hotfix/security-patch main
# Fix issue
git commit -m "Fix security vulnerability CVE-2024-xxx"
git checkout main
git merge --no-ff hotfix/security-patch
git tag -a v1.0.1
git checkout develop
git merge --no-ff hotfix/security-patch
git branch -d hotfix/security-patch
```

**Pros**:
- ✅ Clear separation of concerns
- ✅ Scheduled releases
- ✅ Support for hotfixes
- ✅ Release branches allow QA

**Cons**:
- ❌ Complex for small teams
- ❌ Slower release cycle
- ❌ More branches to manage

---

### GitHub Flow (Continuous Deployment)

```
main (always deployable)
  ↑
  │ (pull request merge)
  │
feature/add-login
feature/fix-bug-123
feature/refactor-auth
```

**Workflow**:
```bash
# Create feature branch
git checkout -b feature/add-login

# Make changes and commit
git commit -m "Add login feature"
git commit -m "Add tests for login"

# Push and create pull request
git push origin feature/add-login

# After PR review and CI passes:
# Merge via GitHub UI (with PR description auto-generated)

# Delete branch
git branch -d feature/add-login

# Deploy immediately to production
# (CI/CD runs on main branch automatically)
```

**Pros**:
- ✅ Simple, easy to understand
- ✅ Continuous deployment
- ✅ Fewer branches
- ✅ Perfect for small teams and startups

**Cons**:
- ❌ Requires excellent CI/CD
- ❌ No staging environment separation
- ❌ All merges go to production

---

### Trunk-Based Development (Aggressive Simplicity)

```
main
  ↓ (commit directly or short-lived branches)
  ├─ feature/user-auth (1-2 days max)
  │   ↓
  ├─ feature/payment (1-2 days max)
  │   ↓
  └─ feature/dashboard (1-2 days max)
```

**Workflow**:
```bash
# Create very short-lived branch (max 1-2 days)
git checkout -b feature/add-login

# Make changes (small, focused)
git commit -m "Add login endpoint"
git push origin feature/add-login

# Create PR immediately
# Get quick review (must be same day)

# Merge to main
git checkout main
git pull origin main
git merge feature/add-login
git push origin main

# Delete branch immediately
git branch -d feature/add-login

# Deploy to production (automated)
```

**Pros**:
- ✅ Minimal merge conflicts
- ✅ Simple branching model
- ✅ Encourages small commits
- ✅ Fastest feedback loop

**Cons**:
- ❌ Requires excellent code discipline
- ❌ Requires fast CI/CD
- ❌ Not suitable for large features

---

## Finding Your Feature Branch Base Commit

### Scenario
You created a feature branch from `main` at commit `abc123`, made many commits (def456, ghi789, jkl012), and now you want to find the original commit you branched from.

### Solution 1: Using `git merge-base` (BEST)

```bash
# Find the common ancestor (merge base) of two branches
git merge-base feature main

# Output: abc123
# This is the commit you branched from!
```

**How it works**:
- `merge-base` finds the most recent common ancestor
- This is the point where your feature branch diverged from main
- This is your **base commit**

### Solution 2: Using `git log --graph` (VISUAL)

```bash
# See visual history
git log --graph --oneline --decorate --all

# Output:
# * abc123 Add feature X (main)
# |\
# | * def456 WIP: Login feature
# | * ghi789 Add tests
# | * jkl012 Fix bug
# |/
# * xyz789 Previous commit

# The commit where lines merge is your base (abc123)
```

### Solution 3: Using `git reflog` (WHEN CREATED)

```bash
# See all branch creations and checkouts
git reflog show feature

# Output:
# abc123 feature@{0}: checkout: moving from main to feature
# 
# The commit before "moving from main to feature" is your base

# Or see the full reflog
git reflog
```

### Solution 4: Using `git log --all` with ancestry-path (ADVANCED)

```bash
# Show commits between your branch and main
git log --oneline feature --not main

# Shows all commits unique to feature
# First commit in output is where it diverged

# Or see commits on main not in your feature
git log --oneline main --not feature
```

### Complete Example

```bash
# You have:
# main:    A -- B -- C -- D
#              \
# feature:      E -- F -- G -- H (current branch)

# To find your base commit:
git checkout feature
git merge-base feature main

# Output: B (commit hash of B)
# Explanation: You branched from B, added E, F, G, H

# Verify:
git log --oneline feature
# H
# G
# F
# E
# B (this is your base)
# A

# Check what's unique in feature (not in main):
git log --oneline feature --not main
# H
# G
# F
# E

# Check what's in main but not feature:
git log --oneline main --not feature
# D
# C
```

### Show Base Commit with Details

```bash
# Get merge base with more info
git log -1 $(git merge-base feature main)

# Output:
# commit abc123def456...
# Author: John Doe <john@example.com>
# Date:   May 1 2026
#
#     Add feature X

# Get commit message only
git log -1 --pretty=format:%B $(git merge-base feature main)
# Output: Add feature X

# Get author only
git log -1 --pretty=format:%an $(git merge-base feature main)
# Output: John Doe
```

### Create an Alias for Easy Access

```bash
# Add to ~/.gitconfig
git config --global alias.base '!git merge-base $1 ${2:-main}'

# Usage:
git base feature        # Shows base of feature against main
git base feature dev    # Shows base of feature against dev

# Or add to ~/.gitconfig manually:
[alias]
    base = !git merge-base $1 ${2:-main}
```

---

## Interview Q&A

### Q1: Explain the difference between Merge and Rebase with a real-world example.

**Answer**:

> "Merge and Rebase are two different ways to integrate changes from one branch to another, with fundamentally different approaches to history:
>
> **MERGE**: Creates a new commit with two parents, preserving the complete history.
>
> **Scenario**: Your main branch has commits A → B → C, and your feature branch has D → E branching from B.
>
> ```
> Before: A → B → C (main)
>              \
>              D → E (feature)
>
> After merge: A → B → C → M (merge commit)
>                  \       /
>                  D → E
> ```
>
> When you run `git merge feature`, Git creates a new commit M that has two parents (C and E). The history shows that these branches existed and when they merged.
>
> **Benefits**: 
> - Shows the complete history
> - Non-destructive (no commits rewritten)
> - Safe for shared/public branches
>
> **REBASE**: Replays commits on top of another branch, creating a linear history.
>
> ```
> Before: A → B → C (main)
>              \
>              D → E (feature)
>
> After rebase: A → B → C → D' → E' (feature)
>                     (linear history)
> ```
>
> When you run `git rebase main`, Git:
> 1. Finds the common ancestor (B)
> 2. Detaches commits D and E
> 3. Replays them on top of C
> 4. Creates new commits D' and E' (new SHAs)
>
> **Benefits**:
> - Clean linear history
> - Easier to read
> - Easier to bisect for bugs
>
> **Drawback**: Rewrites history, so never rebase public branches.
>
> **Real-World Rule**:
> - `git merge`: For main, master, release, and shared branches (safe, preserves history)
> - `git rebase`: For local feature branches (clean history, but only on local work)
>
> **My approach**: 
> - Developers work on feature branches with rebase for clean history
> - When merging to main, use `git merge --no-ff` to create a merge commit showing branch integration
> - This gives us clean feature branch history plus context on when features integrated"

---

### Q2: When would you use Cherry-Pick instead of Merge or Rebase?

**Answer**:

> "Cherry-pick is used when you want to apply **specific commits** from one branch to another without merging the entire branch. It's useful in several scenarios:
>
> **Scenario 1: Hotfix in Production**
> - Production has a critical security bug
> - You fix it in `hotfix/security-patch` branch
> - But main has 50 commits ahead from features in development
> - You don't want all 50 commits in the hotfix
>
> ```bash
> git checkout staging
> git cherry-pick abc123        # Pick only the security fix
> git cherry-pick def456        # Pick tests for security fix
> # Now staging has only the hotfix, not 50 feature commits
> ```
>
> **Scenario 2: Partial Release**
> - Feature A is done and tested
> - Feature B is incomplete
> - Release only Feature A
>
> ```bash
> git checkout release-v1.5
> git cherry-pick feature-a-commit-1
> git cherry-pick feature-a-commit-2
> # Release v1.5 has only Feature A
> ```
>
> **Scenario 3: Undo a Wrong Merge**
> - Merged feature branch by mistake
> - Need to apply only specific commits
>
> ```bash
> git reset --hard before-merge-commit
> git cherry-pick feature-good-commit-1
> git cherry-pick feature-good-commit-2
> # Reapplied only the good commits
> ```
>
> **Scenario 4: Multiple Release Branches**
> - Bug fix needed in main, 1.0-branch, and 0.9-branch
>
> ```bash
> # Fix in main first
> git commit -m \"Fix bug in X\"
> BUG_FIX_COMMIT=$(git rev-parse HEAD)
>
> # Apply to 1.0-branch
> git checkout 1.0-branch
> git cherry-pick $BUG_FIX_COMMIT
>
> # Apply to 0.9-branch
> git checkout 0.9-branch
> git cherry-pick $BUG_FIX_COMMIT
> ```
>
> **Key Differences**:
> - **Merge**: All commits from branch come together
> - **Rebase**: Replays all commits on new base
> - **Cherry-pick**: Pick individual commits, cherry-picked commits get new SHAs
>
> **When NOT to use cherry-pick**:
> - ❌ Regular feature development (use merge/rebase)
> - ❌ If you can use merge-only (cherry-pick creates duplicate commits)
> - ❌ For long-term branches (creates divergence)
>
> **Best Practice**: Cherry-pick is tactical (fixing specific issues), not strategic (integrating branches)."

---

### Q3: Describe a Git Flow branching strategy and when you'd use it vs GitHub Flow.

**Answer**:

> "**Git Flow** is a branching strategy with distinct branch types for different purposes. It's suited for projects with scheduled releases.
>
> **Git Flow Structure**:
>
> ```
> main (production, tagged versions)
>   ↑
>   └─ release/* (release candidates, version bumps)
>        ↑
>        └─ develop (staging/next release)
>              ↑
>              ├─ feature/* (new features)
>              ├─ bugfix/* (non-critical bugs)
>              └─ hotfix/* (critical production bugs)
> ```
>
> **Workflow Example**:
> ```bash
> # Feature development
> git checkout develop
> git checkout -b feature/user-auth
> # ... work on feature ...
> git push origin feature/user-auth
> # Create PR, get review, merge to develop
>
> # Prepare release
> git checkout develop
> git checkout -b release/1.0
> # Update version numbers, changelog
> git commit -m \"Bump version to 1.0.0\"
> git push origin release/1.0
> # Create PR, test, then merge to main
> git checkout main
> git merge --no-ff release/1.0
> git tag -a v1.0.0
> git push origin main --tags
>
> # Merge back to develop
> git checkout develop
> git merge --no-ff release/1.0
> ```
>
> **When to use Git Flow**:
> ✅ Scheduled releases (every 2 weeks, monthly)
> ✅ Multiple versions in production (v1.0 and v1.1 both live)
> ✅ Separate QA/staging environment
> ✅ Enterprise projects with formal release process
> ✅ Large teams needing clear structure
>
> **GitHub Flow** is simpler: just main branch + feature branches.
>
> ```
> main (always production-ready)
>   ↑
>   └─ feature/* (all work happens here)
> ```
>
> **Workflow Example**:
> ```bash
> git checkout -b feature/user-auth
> # ... work ...
> git push origin feature/user-auth
> # Create PR, get review
> # Merge to main (via PR)
> # Deploy to production automatically (CI/CD)
> ```
>
> **When to use GitHub Flow**:
> ✅ Continuous deployment (deploy to production daily/hourly)
> ✅ Automated testing and deployment
> ✅ Small teams (1-5 developers)
> ✅ Startups and SaaS products
> ✅ Always-on services with gradual rollouts
>
> **Comparison**:
>
> | Aspect | Git Flow | GitHub Flow |
> |--------|----------|-------------|
> | Release frequency | Scheduled (monthly) | Continuous (daily) |
> | Branches | Many (develop, release, hotfix) | Few (main + features) |
> | Complexity | High | Low |
> | Team size | Large (5+) | Small (1-5) |
> | CI/CD requirement | Optional | Required |
> | Hotfix process | Dedicated branch | Feature branch from main |
>
> **My choice**: 
> - For startups and DevOps projects: **GitHub Flow** (simple, fast feedback)
> - For enterprise releases: **Git Flow** (structured, scheduled)
> - Increasingly trending towards **GitHub Flow** because most teams now have CI/CD"

---

### Q4: How do you find which commit you branched from?

**Answer**:

> "This is a common real-world problem. You created a feature branch weeks ago, made many commits, and now need to know the original commit you branched from.
>
> **Best Method: `git merge-base`**
>
> ```bash
> git merge-base feature main
> # Output: abc123def456... (the base commit)
> ```
>
> This finds the **common ancestor** - the most recent commit that exists in both branches. This is the commit you branched from.
>
> **Real Example**:
> ```
> main:    A -- B -- C -- D -- E
>              \
> feature:      F -- G -- H -- I (HEAD)
>
> git merge-base feature main
> # Returns: B (commit hash)
> # Explanation: You branched from B and added F, G, H, I
> ```
>
> **Show Details of Base Commit**:
> ```bash
> git log -1 $(git merge-base feature main)
> # Output:
> # commit abc123...
> # Author: John Doe
> # Date: May 1 2026
> #     Add feature X
>
> # Get just the message
> git log -1 --pretty=format:%B $(git merge-base feature main)
> # Output: Add feature X
> ```
>
> **Visual History**:
> ```bash
> git log --graph --oneline --all
> # Shows where branches split visually
> # Look for the commit where feature branch separates from main
>
> # Or count commits in feature not in main:
> git log --oneline feature --not main
> # All commits listed are your new ones
> # The base commit is NOT in this list
> ```
>
> **Create Alias for Easy Access**:
> ```bash
> # Add to ~/.gitconfig
> [alias]
>     base = !git merge-base $1 ${2:-main}
>
> # Usage:
> git base feature        # Shows base against main
> git base feature dev    # Shows base against dev
> ```
>
> **When you'd use this**:
> - Rebase: `git rebase $(git merge-base feature main)`
> - See what you added: `git diff $(git merge-base feature main) feature`
> - Count commits: `git log --oneline $(git merge-base feature main)..feature | wc -l`
> - Squash all your commits: `git rebase -i $(git merge-base feature main)`"

---

### Q5: What are the dangers of Rebase and when should you avoid it?

**Answer**:

> "Rebase is powerful but dangerous if misused. The core danger is **history rewriting** - commits get new SHAs, which breaks synchronization with other developers.
>
> **Danger 1: Rebase on Public/Shared Branches**
>
> ```bash
> # NEVER DO THIS:
> git checkout main
> git rebase develop
>
> # NEVER DO THIS:
> git push origin main
> git rebase feature
> git push origin main --force  # NEVER --force!
> ```
>
> **Why it's dangerous**:
> - Other developers have main checked out
> - Their main has old commit SHAs
> - Your rebase creates new SHAs
> - Merge conflicts for everyone
> - Lost commits appear to happen
>
> **Impact**:
> ```
> Main (before rebase): A -- B -- C -- D
> Your push (after rebase): A -- B' -- C' -- D'
>                                (different SHAs!)
>
> Team members' main:   A -- B -- C -- D
>                            (now \"behind\")
>
> When they pull: MASSIVE CONFLICTS
>                 Git thinks you deleted B, C, D
>                 And added new B', C', D'
> ```
>
> **Danger 2: Rebase Before Understanding Consequences**
>
> ```bash
> git rebase main     # Doesn't seem to do anything visible...
>
> # But now:
> git log --oneline   # All commit SHAs changed!
> git diff origin/feature feature  # Shows all commits different
> ```
>
> **Danger 3: Losing Work with Force Push**
>
> ```bash
> git rebase feature
> git push origin feature --force
>
> # If you made a mistake in rebase:
> # Those commits are gone from remote
> # Other developers' work based on old commits is now broken
> ```
>
> **Safe Rebase Rules**:
>
> ✅ DO rebase:
> - On your own local branches
> - Before opening a pull request
> - On feature branches not yet pushed
> - `git rebase` without `--force` push
>
> ❌ DON'T rebase:
> - After pushing to shared branch
> - On main, master, develop, release branches
> - With `--force` push (NEVER)
> - On branches other people are working on
> - If you're unsure
>
> **Safe Workflow**:
> ```bash
> # Create and work locally
> git checkout -b feature/login
> git commit -m \"Add login endpoint\"
> git commit -m \"Add tests\"
>
> # Update from main locally
> git fetch origin
> git rebase origin/main
>
> # Push FIRST TIME (safe)
> git push origin feature/login
>
> # If conflicts after rebase, you resolve them
> git add .
> git rebase --continue
>
> # DO NOT FORCE PUSH
> git push origin feature/login  # Regular push (safe)
>
> # Create PR and merge normally
> # Never force push again on this branch
> ```
>
> **If You Already Did Wrong Rebase**:
> ```bash
> # Use reflog to find original commits
> git reflog
> # Shows: abc123 HEAD@{0}: rebase -i (abort)
> #        def456 HEAD@{1}: rebase -i (start)
> #        ghi789 HEAD@{2}: checkout: moving from main to feature
>
> # Restore to before rebase
> git reset --hard ghi789
> ```
>
> **Key Takeaway**: Rebase is for local history cleaning before sharing. Once shared with team, use merge to preserve history and avoid conflicts."

---

### Q6: Explain Interactive Rebase and its power.

**Answer**:

> "Interactive rebase (`git rebase -i`) allows you to rewrite history by editing, reordering, squashing, or removing commits. It's incredibly powerful for cleaning up local history before sharing.
>
> **Basic Syntax**:
> ```bash
> git rebase -i HEAD~5
> # Opens editor with last 5 commits
> ```
>
> **Editor Options**:
> ```
> pick abc123 First commit       → Keep as is
> reword def456 Second commit    → Keep but edit message
> squash ghi789 Third commit     → Combine with previous
> fixup jkl012 Fourth commit     → Combine (discard message)
> drop mno345 Fifth commit       → Remove entirely
> edit pqr678 Sixth commit       → Pause for manual edits
> ```
>
> **Use Case 1: Squashing (Combining Commits)**
>
> ```bash
> # Your feature branch has many small commits:
> git log --oneline
> abc123 Add login endpoint
> def456 Fix typo
> ghi789 Add password validation
> jkl012 Fix test
> mno345 Add JWT token
> pqr678 Update docs
>
> # Want to combine into 2 clean commits
> # Use interactive rebase:
> git rebase -i HEAD~6
>
> # Change to:
> pick abc123 Add login endpoint
> squash def456 Fix typo
> squash ghi789 Add password validation
> squash jkl012 Fix test
> pick mno345 Add JWT token
> squash pqr678 Update docs
>
> # Result: 2 commits
> # Commit 1: \"Add login endpoint\" (with all fixes)
> # Commit 2: \"Add JWT token\" (with docs)
> ```
>
> **Use Case 2: Reordering Commits**
>
> ```bash
> # Commits in wrong order:
> git log --oneline
> abc123 Add tests for feature X
> def456 Add feature X
> ghi789 Add database migration
>
> # Reorder in interactive rebase:
> pick ghi789 Add database migration
> pick def456 Add feature X
> pick abc123 Add tests for feature X
>
> # Now logical order: migration → feature → tests
> ```
>
> **Use Case 3: Editing Commit Messages**
>
> ```bash
> # Bad commit message
> git log --oneline
> abc123 wip: trying things
> def456 fix stuff
> ghi789 more code
>
> # Fix messages with interactive rebase:
> git rebase -i HEAD~3
>
> # Change to:
> reword abc123 wip: trying things
> reword def456 fix stuff
> reword ghi789 more code
>
> # Git pauses for each, let you edit message:
> # abc123 becomes: \"Implement user authentication\"\n
> # def456 becomes: \"Fix password hashing bug\"\n
> # ghi789 becomes: \"Add JWT token verification\"\n
> ```
>
> **Use Case 4: Breaking Apart Commits (edit)**
>
> ```bash
> # Have one big commit with multiple features:
> git log --oneline
> abc123 Add login, payments, and notification system (3000 lines!)
>
> # Break it apart:
> git rebase -i HEAD~1
>
> # Change to:
> edit abc123 Add login, payments, and notification system
>
> # Git stops at that commit, you can:
> git reset HEAD~1  # Unstage the commit
> git add -p        # Add parts of changes
> # Stage login feature only
> git commit -m \"Add login system\"
> 
> # Continue with remaining files
> git add -p
> git commit -m \"Add payment processing\"
> 
> # Then continue rebase
> git rebase --continue
>
> # Result: 3 separate commits instead of 1 giant commit
> ```
>
> **Use Case 5: Removing Commits (drop)**
>
> ```bash
> # Have commits you want to remove:
> git log --oneline
> abc123 Add experimental feature
> def456 Revert experimental feature
> ghi789 Add real feature
>
> # Remove both the experimental feature and revert:
> git rebase -i HEAD~3
>
> # Change to:
> drop abc123 Add experimental feature
> drop def456 Revert experimental feature
> pick ghi789 Add real feature
>
> # Result: Experimental feature never happened in history
> ```
>
> **Pro Tips**:
> ```bash
> # Abort rebase if something goes wrong
> git rebase --abort
>
> # Continue after resolving conflicts
> git rebase --continue
>
> # Skip a commit (if merge conflict)
> git rebase --skip
>
> # Verify your rebase before pushing
> git log --oneline
> git diff origin/feature feature  # See what changed
>
> # Shortcut: squash all onto previous commit
> git commit --amend --no-edit
> # Then rebase and squash with previous commit
> ```
>
> **Key Warnings**:
> - ⚠️ Only rebase local commits (before push)
> - ⚠️ Never rebase and force-push to shared branches
> - ⚠️ Team members will have conflicts if you rebase shared branches
> - ✅ Use for cleaning up feature branches before PR"

---

### Q7: How do you handle merge conflicts?

**Answer**:

> "Merge conflicts occur when Git can't automatically merge changes - when the same lines were modified in both branches differently.
>
> **Conflict Markers in Files**:
>
> ```
> <<<<<<< HEAD
> This is from current branch (what you're merging into)
> =======
> This is from other branch (what you're merging from)
> >>>>>>> feature-branch
> ```
>
> **Workflow**:
>
> ```bash
> # Attempt merge
> git merge feature
> # CONFLICT (content): Merge conflict in app.js
> # Automatic merge failed; fix conflicts and then commit the result.
>
> # Check status
> git status
> # Output:
> # On branch main
> # You have unmerged paths.
> #   (use \"git add/rm ...\" as appropriate to resolve)
> #   both modified:   app.js
>
> # Open file and resolve manually
> vim app.js
>
> # After resolving, stage the file
> git add app.js
>
> # Complete the merge
> git commit -m \"Merge feature into main\"
> ```
>
> **Resolve Conflict - 3-Way Merge**:
>
> ```
> Common ancestor (base):
>   function login() { }
>
> Current branch (HEAD):
>   function login() {
>     // Validate email
>     validateEmail(user);
>   }
>
> Other branch:
>   function login() {
>     // Check password
>     checkPassword(user);
>   }
>
> Conflict marker:
> <<<<<<< HEAD
>   // Validate email
>   validateEmail(user);
> =======
>   // Check password
>   checkPassword(user);
> >>>>>>> feature
>
> Resolution (keep both):
>   // Validate email
>   validateEmail(user);
>   // Check password
>   checkPassword(user);
> ```
>
> **Tools for Conflict Resolution**:
>
> ```bash
> # Use visual merge tool
> git config merge.tool vimdiff
> git mergetool
> # Opens side-by-side comparison for each conflict
>
> # Or use VS Code
> git config merge.tool vscode
> git config mergetool.vscode.cmd 'code --wait \\$MERGED'
> git mergetool
>
> # Abort if too complicated
> git merge --abort
>
> # Ours (keep our changes, discard theirs)
> git checkout --ours app.js
> git add app.js
> git commit -m \"Keep our version of app.js\"
>
> # Theirs (keep their changes, discard ours)
> git checkout --theirs app.js
> git add app.js
> git commit -m \"Accept their version of app.js\"
> ```
>
> **During Rebase**:
>
> ```bash
> git rebase main
> # CONFLICT (content): Merge conflict in app.js
>
> # Fix conflict
> vim app.js
> git add app.js
>
> # Continue rebase (not commit)
> git rebase --continue
>
> # Or abort rebase
> git rebase --abort
> ```
>
> **Prevent Conflicts**:
> - ✅ Small, focused branches (high conflict risk = too many changes)
> - ✅ Rebase frequently to pick up latest from main
> - ✅ Clear communication about who's changing what
> - ✅ Code reviews to catch issues before merge
> - ✅ Short-lived branches (max 2-3 days)
>
> **View Conflict History**:
>
> ```bash
> # See how it was resolved before
> git log --all -S 'conflicting text' --oneline
> # Shows previous commits that touched this code
>
> # See how file looked before merge
> git show :1:app.js  # Common ancestor version
> git show :2:app.js  # Current branch version
> git show :3:app.js  # Other branch version
> ```"

---

### Q8: What's the difference between `git fetch`, `git pull`, and `git pull --rebase`?

**Answer**:

> "These three commands are often confused but they do different things:
>
> **`git fetch`**: Download remote changes WITHOUT integrating them
>
> ```bash
> git fetch origin
> # Downloads all commits from origin into origin/main (remote tracking branch)
> # YOUR local main is NOT changed
> # You can review changes before integrating
>
> # Check what's new
> git log origin/main --not main
> # Shows commits in origin/main that aren't in your main
>
> # Review before merging
> git diff main origin/main
>
> # Then manually decide to merge
> git merge origin/main
> ```
>
> **`git pull`**: Fetch + Merge (creates merge commit)
>
> ```bash
> git pull origin main
> # Equivalent to:
> git fetch origin
> git merge origin/main
>
> # Results in merge commit
> Before: A -- B -- C (main)
>             └─ D (origin/main, fetched)
>
> After: A -- B -- C -- M (merge commit)
>                   \ /
>                   D
> ```
>
> **`git pull --rebase`**: Fetch + Rebase (clean linear history)
>
> ```bash
> git pull --rebase origin main
> # Equivalent to:
> git fetch origin
> git rebase origin/main
>
> # Results in linear history
> Before: A -- B -- C -- D (main, made local commits D)
>             └─ E -- F (origin/main, new commits on remote)
>
> After:  A -- B -- E -- F -- D' -- C' (linear, D and C rebased)
> ```
>
> **Comparison**:
>
> | Command | Action | Result | Use Case |
> |---------|--------|--------|----------|
> | `git fetch` | Download only | Remote tracking updated | Review before integrating |
> | `git pull` | Download + Merge | Merge commit created | Quick update (messy history) |
> | `git pull --rebase` | Download + Rebase | Linear history | Clean history |
>
> **Visual Difference**:
>
> ```
> Starting state:
> Local main:   A -- B -- C (HEAD)
> Origin/main:  A -- B -- D -- E
>
> After git pull (merge):
> Local main:   A -- B -- C -- M (merge commit)
>                   \\      /
>                    D -- E
>
> After git pull --rebase:
> Local main:   A -- B -- D -- E -- C' -- B' (rebased locally)
>                     (linear)
> ```
>
> **My Recommendation**:
>
> ```bash
> # Always fetch first to review
> git fetch origin
> git log origin/main --not main  # See what's new
> git diff main origin/main      # See what changed
>
> # Then decide:
> # For clean history: git rebase origin/main
> # For preserving merges: git merge origin/main
> # Or configure default:
> git config pull.rebase true  # Always rebase on pull
>
> # Then simple:
> git pull  # Uses rebase by default
> ```
>
> **Pro Workflow**:
> ```bash
> # Configure once
> git config --global pull.rebase true
> git config --global rebase.autostash true  # Auto-stash changes
>
> # Now pulling is safe
> git pull  # Automatically rebases with clean history
>
> # If you want to merge specific time
> git pull --no-rebase origin main  # Merge despite config
> ```"

---

## Real-World Scenarios

### Scenario 1: Emergency Hotfix to Production

**Situation**: Critical bug in production, need fix ASAP while feature work continues on develop.

```bash
# 1. Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug-fix

# 2. Make minimal fix
git commit -m \"Fix: Critical bug in payment processing\"

# 3. Test locally
npm test

# 4. Create PR (expedited review)
git push origin hotfix/critical-bug-fix
# Create PR with \"HOTFIX\" label

# 5. Merge to main (directly or via PR)
git checkout main
git pull origin main
git merge --no-ff hotfix/critical-bug-fix
git tag -a v1.0.1 -m \"Hotfix: Payment bug\"
git push origin main --tags

# 6. Deploy to production
git checkout production
git merge main
git push origin production

# 7. Merge back to develop (important!)
git checkout develop
git pull origin develop
git merge --no-ff hotfix/critical-bug-fix
git push origin develop

# 8. Delete hotfix branch
git branch -d hotfix/critical-bug-fix
git push origin --delete hotfix/critical-bug-fix
```

### Scenario 2: Feature Branch Needs Latest from Main

**Situation**: Working on feature, but main has important updates from other teams.

```bash
# Option A: Merge (preserves branch existence)
git checkout feature/my-feature
git fetch origin
git merge origin/main
# If conflicts, resolve them
git add .
git commit -m \"Merge main into feature/my-feature\"
git push origin feature/my-feature

# Option B: Rebase (clean history, only if not pushed yet)
git checkout feature/my-feature
git fetch origin
git rebase origin/main
# If conflicts, resolve them
git add .
git rebase --continue
git push origin feature/my-feature
# Note: Only works if feature not yet pushed or on local copy
```

### Scenario 3: Accidentally Committed to Main Instead of Feature

**Situation**: Made commits directly to main instead of feature branch.

```bash
# 1. Find out where you are
git log --oneline -5
# abc123 Wrong commit 3
# def456 Wrong commit 2
# ghi789 Wrong commit 1
# jkl012 Good commit (actual main HEAD before your mistakes)

# 2. Create feature branch at current location
git branch feature/accidental-work

# 3. Reset main to before mistakes
git reset --hard jkl012

# 4. Push the reset (dangerous, use with caution)
git push origin main --force-with-lease

# 5. Work continues on feature branch
git checkout feature/accidental-work
git push origin feature/accidental-work
# Create PR normally

# Better approach to prevent this:
git config --global init.defaultBranch main
git checkout -b feature/name  # Create new branch explicitly
# Never commit to main directly unless authorized
```

### Scenario 4: Finding Which Commit Introduced a Bug

**Situation**: Bug exists in production, need to find when it was introduced.

```bash
# Use git bisect for binary search
git bisect start
git bisect bad HEAD        # Current commit has bug
git bisect good v1.0       # This version was good

# Git checks out commits between good and bad
# Test each one
# Mark as good or bad
git bisect good
# or
git bisect bad

# Continue until Git narrows it down
# Output: abc123 is the first bad commit

# Examine the culprit
git show abc123
git log abc123 -5 --oneline

# End bisect
git bisect reset
```

---

## Git Troubleshooting

### Undo Last Commit (Not Yet Pushed)

```bash
# Keep changes, undo commit
git reset --soft HEAD~1
# Changes still staged

# Keep changes, undo commit and staging
git reset HEAD~1
# Changes unstaged

# Discard changes entirely
git reset --hard HEAD~1
```

### Find Lost Commits

```bash
# Commits are in reflog for 90 days
git reflog
# Shows all branch movements

# Recover deleted branch
git reflog show deleted-branch
# Find the commit SHA
git checkout -b recovered-branch abc123
```

### Remove Secret from Git History

```bash
# Remove secret.key from all commits
git filter-branch --tree-filter 'rm -f secret.key' HEAD
git push origin main --force

# Better: Use git filter-repo (faster)
pip install git-filter-repo
git filter-repo --path secret.key --invert-paths
```

---

## Summary Table

| Command | Purpose | Danger Level |
|---------|---------|-------------|
| `git merge` | Combine branches | ✅ Safe |
| `git rebase` | Replay commits | ⚠️ Rewrites history |
| `git cherry-pick` | Pick specific commits | ⚠️ Creates duplicates |
| `git reset --hard` | Discard changes | 🔴 Destructive |
| `git filter-branch` | Rewrite entire history | 🔴 Very destructive |
| `git rebase --interactive` | Edit history | ⚠️ Rewrites commits |
| `git push --force` | Override remote | 🔴 Breaks team sync |

---

**This guide covers Git at production level. Master these concepts and you'll excel in any DevOps/SRE role!**
