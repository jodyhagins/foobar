---
name: to-prd
description: Turn the current conversation context into a PRD file under prds/. Use when user wants to create a PRD from the current context, typically right after a grill-me session.
---

This skill takes the current conversation context and codebase understanding and produces a PRD. Do NOT interview the user — just synthesize what you already know.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already.

2. Sketch out the major modules you will need to build or modify to complete the implementation. Actively look for opportunities to extract deep modules that can be tested in isolation.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

Check with the user that these modules match their expectations. Check with the user which modules they want tests written for.

3. Write the PRD using the template below and add it to the collection of PRDs in `prds/<slug-for-this-prd>.md`

The PRD is read later by a fresh session that has none of this conversation, so it must stand on its own. If the conversation was driven by a brief (a file given to grill-me, a header that fixes an API, a document that pins dependencies), cite that file by path in the sections it governs and say what it fixes. Everything the brief settled is a decision here, not a question.

<prd-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets that describe the implementation; they go stale. The exception is anything a brief fixed: a public API, a pinned dependency, a required file. For those, cite the brief by path and quote only what a reader needs to find it.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)
- How the tests are run (the exact configure, build and test commands, or the presets), because a later step turns each of these into a script

## Out of Scope

A description of the things that are out of scope for this PRD. Name every deliberate absence, so nobody fills the silence.

## Further Notes

Any further notes about the feature.

</prd-template>
