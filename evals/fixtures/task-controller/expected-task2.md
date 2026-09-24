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
