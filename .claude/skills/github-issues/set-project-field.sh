#!/usr/bin/env bash
# Set a field on an issue's item in the "Pragmatic Papers Development" board.
#
#   set-project-field.sh <issue-number> <field> <value>
#   set-project-field.sh <issue-number> <field> --clear
#
#   set-project-field.sh 953 Priority P2
#   set-project-field.sh 953 Size M
#   set-project-field.sh 953 Estimate 3
#   set-project-field.sh 953 "Start date" 2026-10-01
#
# Every ID (project, item, field, option) is looked up by name at runtime, so
# renamed options or a recreated field can't leave a stale ID behind. Adds the
# issue to the board first if it isn't on it. Needs the `project` token scope.
set -euo pipefail

OWNER=digitalgroundgame
REPO=pragmatic-papers
PROJECT=3

if [[ $# -ne 3 ]]; then
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi
issue=$1 field=$2 value=$3

project_id=$(gh project view "$PROJECT" --owner "$OWNER" --format json --jq .id)

item_id=$(gh api graphql -F n="$issue" -f query='
  query($n: Int!) {
    repository(owner: "'"$OWNER"'", name: "'"$REPO"'") {
      issue(number: $n) { projectItems(first: 20) { nodes { id project { number } } } }
    }
  }' --jq ".data.repository.issue.projectItems.nodes[] | select(.project.number == $PROJECT) | .id")

if [[ -z $item_id ]]; then
  item_id=$(gh project item-add "$PROJECT" --owner "$OWNER" \
    --url "https://github.com/$OWNER/$REPO/issues/$issue" --format json --jq .id)
  echo "added #$issue to project $PROJECT" >&2
fi

# gh's built-in --jq, so jq itself doesn't need to be installed.
fields() { gh project field-list "$PROJECT" --owner "$OWNER" --format json --jq "$1"; }
match=".fields[] | select(.name == \"$field\")"

field_id=$(fields "$match | .id")
if [[ -z $field_id ]]; then
  echo "no field named \"$field\" on project $PROJECT. Fields: $(fields '[.fields[].name] | join(", ")')" >&2
  exit 1
fi
field_type=$(fields "$match | .type")

edit=(gh project item-edit --project-id "$project_id" --id "$item_id" --field-id "$field_id")

if [[ $value == --clear ]]; then
  "${edit[@]}" --clear >/dev/null
elif [[ $field_type == ProjectV2SingleSelectField ]]; then
  option_id=$(fields "$match | .options[] | select(.name == \"$value\") | .id")
  if [[ -z $option_id ]]; then
    echo "\"$value\" isn't an option of $field. Options: $(fields "$match | [.options[].name] | join(\", \")")" >&2
    exit 1
  fi
  "${edit[@]}" --single-select-option-id "$option_id" >/dev/null
else
  data_type=$(gh api graphql -f query='
    query { organization(login: "'"$OWNER"'") { projectV2(number: '"$PROJECT"') {
      field(name: "'"$field"'") { ... on ProjectV2Field { dataType } } } } }' \
    --jq .data.organization.projectV2.field.dataType)
  case $data_type in
    NUMBER) "${edit[@]}" --number "$value" >/dev/null ;;
    DATE) "${edit[@]}" --date "$value" >/dev/null ;;
    TEXT) "${edit[@]}" --text "$value" >/dev/null ;;
    *)
      echo "$field is a $data_type field; set it on the issue itself (gh issue edit), not the board." >&2
      exit 1
      ;;
  esac
fi

[[ $value == --clear ]] && echo "#$issue $field cleared" || echo "#$issue $field → $value"
