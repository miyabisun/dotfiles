# workflow のパターン

## 逐次的な workflow

複雑なタスクでは、操作を明確な逐次の手順へ分ける。SKILL.md の冒頭付近で処理の
全体像を Claude に示すと役立つことが多い:

```markdown
Filling a PDF form involves these steps:

1. Analyze the form (run analyze_form.py)
2. Create field mapping (edit fields.json)
3. Validate mapping (run validate_fields.py)
4. Fill the form (run fill_form.py)
5. Verify output (run verify_output.py)
```

## 条件分岐のある workflow

分岐のあるタスクでは、判断点を通して Claude を導く:

```markdown
1. Determine the modification type:
   **Creating new content?** → Follow "Creation workflow" below
   **Editing existing content?** → Follow "Editing workflow" below

2. Creation workflow: [steps]
3. Editing workflow: [steps]
```
