# Localization Rules

## Purpose
Rules for handling all user-visible text in this project.

---

## String Localization Is Mandatory

All user-visible text must use `LocalizedStringKey` or `String(localized:)`. Hardcoded strings in SwiftUI Views are not allowed.

```swift
// ✅
Text("note_detail_save_button")

// ❌
Text("Save")
```

---

## Where to Define Strings

All strings are defined in:
```
NotesTakingAppiOS/Localizable.xcstrings
```

This is the Xcode String Catalog format, which supports automatic extraction and management.

---

## Naming Convention

Use descriptive, prefixed keys:

Pattern: `<screen>_<component>_<type>`

```
// ✅
"note_detail_title_label" = "Note";
"home_empty_state_message" = "No notes yet";
"folders_create_button_label" = "New Folder";

// ❌
"title" = "Note";
"button1" = "New Folder";
```

---

## Plural Strings

Use `LocalizedStringKey` with pluralization support in `.xcstrings` catalog:

```
"notes_count %lld" — with plural variants for one/other
```

---

## Dynamic Content

For strings with dynamic values, use format arguments:

```swift
Text("note_shared_by \(ownerName)")
```

---

## Accessibility Labels

Provide `accessibilityLabel` for all non-text interactive elements (icons, image buttons) to support VoiceOver:

```swift
Button(action: onDelete) {
    Image(systemName: "trash")
}
.accessibilityLabel(Text("note_delete_icon_description"))
```

---

## Localization Verification

Run the automated check for every user-visible copy change:

```bash
bash harness/scripts/check-localization-rules.sh
```

When a diff adds or changes localized copy, review only the semantic risks it
introduces: ownership in `Localizable.xcstrings`, descriptive key naming, plural and
format-argument behavior, and VoiceOver labels for non-text controls. The
full-source rules bundle is the required CI evidence; review and merge approval are
handled in the review workflow.
