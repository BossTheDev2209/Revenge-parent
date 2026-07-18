---
name: superpowers-framework
description: Use this skill when building software features, debugging, testing, or collaborating with multiple agents. Activates the complete Superpowers methodology for systematic development with test-driven practices.
---

# Superpowers Framework

A complete software development methodology for coding agents built on composable skills and systematic workflows.

## Core Philosophy

- **Test-Driven Development**: Write tests first, always
- **Systematic over ad-hoc**: Process over guessing
- **Complexity reduction**: Simplicity as primary goal  
- **Evidence over claims**: Verify before declaring success

## When to Activate Superpowers

Activate this skill when:
- Starting a new feature or project
- Building anything that needs verified correctness
- Working with multiple agents or subagents
- Debugging complex issues systematically
- Writing code that needs test coverage
- Making architectural decisions

**Do NOT skip any step** — each phase builds on the previous one and prevents costly mistakes.

## The Complete Workflow

### 1. Brainstorming (Clarify Intent)

**Trigger condition**: Before writing ANY code, when requirements are vague or partially defined

**What to do**:
- Don't jump to code. Ask clarifying questions first.
- Use Socratic method: what's the actual problem? Who uses it? What would success look like?
- Explore design alternatives and tradeoffs
- Refine rough ideas into a concrete specification
- Present design document in short, digestible sections
- Get explicit sign-off before proceeding

**Key questions to answer**:
- What problem are we solving?
- Who is the user/customer?
- What are the edge cases?
- How will we know it works?
- What constraints exist (performance, compatibility, etc.)?

**Deliverable**: Approved design document with explicit stakeholder sign-off

---

### 2. Git Worktree Setup (Isolate Work)

**Trigger condition**: After design approval, before touching code

**What to do**:
- Create a new git worktree (isolated branch workspace)
- Run full project setup (dependencies, environment, build tools)
- Verify the test suite passes with no failures (baseline)
- Commit the worktree creation so recovery is possible

**Why**: Isolated environments prevent conflicts and enable parallel work

**Deliverable**: Clean, verified baseline branch ready for development

---

### 3. Writing Plans (Decompose Work)

**Trigger condition**: Immediately after design approval

**What to do**:
- Break design into bite-sized tasks: **2-5 minutes each**
- For every task, specify:
  - **Exact file paths** to modify
  - **Complete code** to write (not pseudocode)
  - **Verification steps** (how to test each change)
  - **Success criteria** (what passing looks like)
- Emphasize TDD: test must be written and fail first
- Apply YAGNI: only build what's in the approved design
- Apply DRY: no code duplication across tasks
- Review: can a junior engineer with no context follow this?

**Decomposition rules**:
- Each task is atomic (completes one logical change)
- No task depends on unclear setup
- Verification is explicit and testable
- No "do whatever makes sense" — be specific

**Deliverable**: Detailed task list with exact code and test specs

---

### 4. Subagent-Driven Development (Execute with Verification)

**Trigger condition**: With approved plan and confirmed start

**Workflow**:
1. Dispatch a **fresh subagent** for each task
2. Give subagent:
   - The specific task (2-5 minutes of work)
   - The exact code it needs to write
   - The verification steps
   - The broader project context
3. Subagent executes task
4. **Two-stage review**:
   - **Stage 1 (Spec compliance)**: Does implementation match the plan exactly?
   - **Stage 2 (Code quality)**: Is the code clean, tested, follows patterns?
5. If either stage fails: route back to subagent for fixes
6. If both pass: commit, move to next task
7. Subagent works autonomously; human checkpoint after every 3-5 tasks

**Key practice**: Don't manually verify every task — subagents review spec compliance first, then code quality. This creates early feedback loops.

**Alternative: Executing-Plans (Batch Mode)**:
If subagents aren't available, use batch execution:
- Execute tasks in sequence with human checkpoints
- Same verification, human-driven pacing
- Takes longer but same rigor

**Deliverable**: Completed, tested code matching the plan

---

### 5. Test-Driven Development (RED-GREEN-REFACTOR)

**Trigger condition**: During implementation (for every task)

**Enforce this cycle**:

1. **RED**: Write a test that fails
   - Test specifies behavior, not implementation
   - Run it, watch it fail
   - Commit the failing test

2. **GREEN**: Write minimal code to pass
   - Only write code the test requires
   - Run test, watch it pass
   - No extra features, no future-proofing
   - Delete any code written before the test

3. **REFACTOR**: Improve while keeping test green
   - Extract duplicated code
   - Rename for clarity
   - Improve performance if needed
   - Run test constantly; it must never break

**Anti-patterns to prevent**:
- Writing code without tests
- Tests that are too broad (multiple assertions)
- Testing implementation details instead of behavior
- Tests that depend on each other
- Skipping refactor after green passes

**Every task must follow RED-GREEN-REFACTOR** or it doesn't count as done.

**Deliverable**: Fully tested code with passing test suite

---

### 6. Requesting Code Review (Pre-Review Checklist)

**Trigger condition**: Between major tasks or before merge

**What to do**:
- Review own code against the original plan
- Create a checklist:
  - [ ] All tests pass
  - [ ] Code matches plan exactly
  - [ ] No unnecessary features (YAGNI)
  - [ ] No code duplication (DRY)
  - [ ] Naming is clear
  - [ ] Edge cases handled
  - [ ] Performance acceptable
- Report issues by severity:
  - **Critical**: Blocks merge (breaks design)
  - **Major**: Should fix before merge
  - **Minor**: Nice to have
- Request review from designated reviewer with context

**Deliverable**: Code review request with clear issue categorization

---

### 7. Receiving Code Review (Response Workflow)

**Trigger condition**: When code review feedback arrives

**What to do**:
- Categorize feedback as critical/major/minor
- For critical issues: pause, fix immediately, re-verify all tests
- For major issues: fix in same task or create follow-up task
- For minor issues: decide: fix now or log for later?
- For suggestions: understand reasoning; push back if needed
- Never ignore feedback — address or document decision
- Commit fixes and re-request review if issues were critical/major

**Deliverable**: Addressed feedback with explanations for any items declined

---

### 8. Finishing the Development Branch (Merge Workflow)

**Trigger condition**: When all tasks complete and tests pass

**What to do**:
1. **Verify**:
   - Full test suite passes
   - No regressions in unrelated tests
   - Code matches approved design
   - No debugging prints or TODO comments

2. **Present options** to human:
   - Merge to main immediately
   - Create a pull request for review
   - Keep branch for further work
   - Discard and start over

3. **If merging**:
   - Write clear commit message (what + why, not how)
   - Include task numbers/references
   - Verify CI passes

4. **Clean up**:
   - Delete the git worktree
   - Close any tracking issues

**Deliverable**: Merged code or prepared PR ready for review

---

## Systematic Debugging Skill

**Trigger condition**: When code fails, produces unexpected output, or test won't pass

**Four-phase process**:

### Phase 1: Reproduce (Evidence)
- Write a test that reproduces the bug
- Understand exact conditions (specific inputs, state, sequence)
- Document baseline behavior vs. expected
- Never skip this; unclear bugs lead to wrong fixes

### Phase 2: Hypothesize (Theory)
- Examine code flow
- Identify suspicious areas
- List 3+ hypotheses, ranked by likelihood
- Choose most likely and test it first

### Phase 3: Isolate (Narrowing)
- Add strategic logging/debugging
- Verify hypothesis: Is your theory right?
- If wrong, test next hypothesis
- Keep narrowing until you find root cause

### Phase 4: Fix & Verify (Solution)
- Apply minimal fix addressing root cause
- Verify the test now passes
- Check for regressions (other tests still pass?)
- Understand why it happened (prevent recurrence)
- Write documentation if it's a non-obvious issue

**Never apply band-aids** — understand and fix the root cause.

---

## Verification Before Completion

**Trigger condition**: After bug fix or feature completion

**Checklist**:
- [ ] The specific issue is resolved
- [ ] No new test failures introduced
- [ ] Performance is acceptable
- [ ] Edge cases are handled
- [ ] Code matches style/patterns of codebase
- [ ] Documentation updated if needed

**Before declaring done**:
- Run full test suite
- Manually test the specific scenario if possible
- Verify fixes would catch regressions

---

## Skills for Parallelization

### Dispatching Parallel Agents

**When**: Multiple independent tasks can run simultaneously

**What to do**:
- Identify independent work units
- Create separate subagent requests (one per task)
- Provide each subagent full context
- Collect results and integrate
- Run full test suite to verify integration

**Example**: 
- Agent A: Write database schema migration
- Agent B: Write API endpoints (in parallel)
- Then: Integration test to verify they work together

### Using Git Worktrees

**Why**: Multiple agents can work on separate branches simultaneously without conflicts

**Setup**:
- Main development uses separate worktree per major feature
- Each worktree is isolated filesystem and git branch
- Agents work independently
- Merge when ready

---

## Writing Your Own Skills

**When to write a new skill**:
- Technique wasn't obvious to you
- You had to debug it or experiment
- You expect to use it more than once
- It prevents a category of mistakes

**Structure**:
1. **Name**: Clear, hyphenated, lowercase
2. **Trigger rules**: When to activate (be specific)
3. **Steps**: Numbered, action-oriented process
4. **Verification**: How to know you did it right
5. **Common mistakes**: Anti-patterns to avoid

**Test your skill** with a subagent before publishing.

---

## When Superpowers Works Best

✅ **Great for**:
- New features in existing codebases
- Building something from scratch
- Team collaboration on complex features
- Code that must be correct (production, safety-critical)
- Mentoring junior developers

⚠️ **Adjust for**:
- Spike/exploratory work (lighter brainstorming)
- Trivial 1-line fixes (skip planning overhead)
- Familiar code patterns (still write tests)

---

## The Speed Advantage

You might think systematic development is slower. In practice:
- **Brainstorming prevents rework** (no wrong architectures)
- **Planning prevents false starts** (agents work autonomously)
- **TDD catches bugs early** (cheap to fix before integration)
- **Code review prevents merge-day disasters** (parallel work)
- **Parallel agents compress timeline** (multiple tasks simultaneously)

Result: **Complex features complete faster and with fewer bugs**.

---

## Anti-Patterns to Avoid

❌ **Skip brainstorming** — leads to redesigns mid-implementation
❌ **Write code before tests** — discovers issues too late
❌ **Vague plans** — agents waste time on interpretation
❌ **No code review** — defects slip into main
❌ **Manual verification only** — misses edge cases
❌ **One agent per feature** — no parallel progress
❌ **No git worktree isolation** — merge conflicts and regressions

---

## Quick Reference: Workflow Checklist

- [ ] **Brainstorm**: Requirements clear? Design approved?
- [ ] **Setup**: Git worktree created? Tests baseline passes?
- [ ] **Plan**: Tasks written with exact code/tests? Signed off?
- [ ] **Implement**: TDD cycle? Tests failing then passing?
- [ ] **Review**: Code matches plan? Tests passing? Quality good?
- [ ] **Integrate**: Full suite passes? No regressions?
- [ ] **Finish**: Merge or PR? Worktree cleaned? Done.

---

## Getting Started

1. **For Claude Code**: Install the plugin via marketplace or run `/plugin install superpowers@claude-plugins-official`
2. **Next project**: Start with brainstorming, not coding
3. **First feature**: Follow this workflow end-to-end
4. **Iterate**: Adjust practices based on your team's needs

The methodology scales from 1-person projects to large teams. Stick to it especially when you're tempted to skip steps — those are the moments it matters most.
