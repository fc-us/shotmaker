---
type: screenshot
tag: notes
app: Google Chrome
captured: 2026-04-03 00:51:29
source: /Users/andrew-mbp/Desktop/Screenshot 2026-04-03 at 12.51.14 AM.png
---

# Product Deep Dive

**App:** Google Chrome  
**Tag:** notes  
**Captured:** 2026-04-03 00:51:29  
**File:** `Screenshot 2026-04-03 at 12.51.14 AM.png`

## Extracted Text

Product Deep Dive
Everything Is an Entity with a Type
One universal data model powers infinite verticals.
Entity
The universal base type
name
string
type
enum
metadata
JSONB
relationships
polymorphic
engagement_score
float
Person
email, phone, country
Group
members, meeting_day
Organization
handle, vertical, staff
Course
chapters, enrollment
Video
duration, transcript
Form
fields, submissions
Note
body, wikilinks
Place
lat, Ing, address
Relationship Graph
Every entity connects to every other entity through typed relationships.
Task
due_date, assignee
Project
status, milestones
W
Wei Chen
Person • Student
Karen Johnson
Person •
friendship_partner
IFI Columbus
Organization •
member_of
CS 101 Study Group
Group • member_of
Bible Study Video
Video • mentioned_in
New vertical = new type configuration, not new code. The FMEO ontology validated 13 entity classes across 12 countries
before this software existed.
