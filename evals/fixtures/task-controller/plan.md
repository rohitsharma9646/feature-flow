# Plan: task-section fixture

## Outcome gate

An example block that must not be taken as the real section:

```markdown
## Global Constraints
- fake constraint inside a fence
```

## Global Constraints

- Use the project logger, never `console.log`.
- Exit codes: 0 success, 2 usage error.

## Tasks

### Task 1: First task

**Interfaces:**
- Consumes: none
- Produces: `greet(name)`

- [ ] **Step 1:** Write `greet`.

### Task 2: Edit a markdown template

- [ ] **Step 1:** Backtick fence, indented inside the list item:
  ```markdown
  ### Task 3: fake heading in a backtick fence
  ## Global Constraints
  ```
- [ ] **Step 2:** Tilde fence (a backtick line does not close it):
  ~~~
  ### Task 9: fake heading in a tilde fence
  ```
  # still inside the tilde fence
  ~~~
- [ ] **Step 3:** Four-backtick fence holding a three-backtick fence:
````md
```
### Task 4: fake heading in a nested fence
```
## Dependency graph
````
- [ ] **Step 4: Verify** — **Run:** `true` **Expected:** exit 0

### Task 3: Real third task

- [ ] **Step 1:** Real work.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
