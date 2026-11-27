# Java Quiz & Examination Management System

A console-based Java application where **administrators** manage users, subjects and classes, **teachers** build question banks and timed examinations and grade them, and **students** take their assigned exams and view their released results. It was built as a group OOP project: Java 17, no external libraries, and data saved to files.

## Quick start

Requirements: **JDK 17 or newer** (`java -version` and `javac -version`).

**Linux / macOS**

```bash
./run.sh --demo
```

**Windows**

```bat
run.bat --demo
```

`--demo` adds demonstration records the first time it runs, when the data folder is still empty. Leave it out to start with a blank system; the app then asks you to create the first administrator account.

| Demo account | Username | Password |
|---|---|---|
| Administrator | `admin` | `Admin123` |
| Teacher | `teacher1` | `Teacher123` |
| Students | `student1`, `student2`, `student3` | `Student123` |

The demo exam **"OOP Quiz 1"** has one question of each of the 9 types, a 15-minute timer with auto-submit, pausing allowed, and 2 attempts.

### Other commands

```bash
./run.sh test              # compile and run the 84 automated tests
./run.sh build             # compile only (classes go to ./out)
./run.sh --data mydata     # use a different data folder
```

Without the scripts:

```bash
javac --release 17 -d out $(find src -name "*.java")
java -cp out main.Main
```

**IDE:** mark `src` (and `test` if you want the tests) as source roots and run `main.Main`. In IDE consoles passwords are visible while you type; in a real terminal they are hidden.

## Features

| Area | What works |
|---|---|
| Accounts | Login/logout, separate admin/teacher/student menus, PBKDF2 salted password hashing, password change, lockout after 5 failed logins, duplicate username and student-number checks, first-run admin setup |
| Users | Add, view, edit, activate/deactivate, reset password, delete (blocked if the user has history), search by name/username/ID/student number |
| Subjects & classes | Create, edit and delete subjects; assign teachers; enrol students individually or a whole class; search and sort |
| Question bank | 9 types: Multiple Choice, Multiple Select (optional partial credit), True/False, Identification, Fill in the Blanks, Enumeration (auto or manual), Essay, Matching, Numerical (with tolerance). Points, category, difficulty, explanation. Validated before saving. Search and filter |
| Exams | Draft → Published → Active → Completed → Archived. Instructions, passing %, schedule, max attempts, question/choice shuffling, preview, assign to students, classes or a whole subject, publish/unpublish/close/archive/delete |
| Timer | Presets from 5 minutes to 2 hours plus custom (`01:15:30`, `1h15m`, `50`). Auto-submit on/off, optional pausing, warnings at 10/5/1 minutes. The deadline is stored in the session, so it never resets when you move between questions or restart the app. Duplicate-submission protection. Manual and automatic submissions are labelled |
| Taking an exam | Instructions page, next/previous/go-to navigation, answer, clear, flag for review, review list, confirmation before overwriting an answer, autosave on every change, resume after closing the app |
| Grading | Automatic grading of objective types; manual grading of essays and manual enumerations with feedback; results stay *pending* until manual grading is complete; release, or automatic release |
| Reports | Exam statistics (average, highest, lowest, pass/fail rate, completion, per-question average), ranking from highest to lowest, filter by subject/class/exam, class performance, student attempt history, system summary, export to `.txt` |
| Persistence | Java serialization in `data/*.dat`, safe writes (temp file + `.bak`), recovery from corrupted files, manual backup |

## Project layout

```
src/main        Main.java – entry point (argument parsing and wiring only)
src/models      User ▸ Admin/Teacher/Student · Question ▸ ChoiceQuestion ▸ … (9 types)
                Subject, SchoolClass, Exam, TimerSettings, ExamSession, StudentAnswer,
                Result, QuestionScore, GradeOutcome, enums
src/services    AccessControl, AuthenticationService, UserService, SubjectService,
                QuestionBankService, ExamService, ExamSessionService, GradingService,
                ReportService, ServiceRegistry, DemoDataSeeder
src/data        FileManager (all disk I/O), DataStore (in-memory collections), IdGenerator
src/exceptions  QuizSystemException + 9 custom exceptions
src/util        PasswordHasher, InputValidator, TimeFormatter, TextUtil
src/ui          ConsoleMenu, RoleMenu, ScreenBase, BaseMenu, AdminMenu, TeacherMenu,
                StudentMenu, ExamInterface, ExamTimer, QuestionForm, ReportScreens,
                InputReader, TablePrinter
test/tests      TestRunner + 7 test suites (fake clock for timer tests)
docs/           DESIGN.md, uml/class-diagram.md, TESTING.md
data/           runtime data (created automatically, git-ignored)
```

## Where each OOP requirement is shown

| Requirement | Where to look |
|---|---|
| Classes and objects | 74 classes across 7 packages |
| Inheritance | `User` → `Admin`, `Teacher`, `Student` · `Question` → `ChoiceQuestion` → `MultipleChoiceQuestion`/`MultipleSelectQuestion` · `QuizSystemException` → 9 subclasses · `ScreenBase` → `BaseMenu` → role menus |
| Abstract classes and interfaces | `User`, `Question`, `ChoiceQuestion`, `ScreenBase`, `BaseMenu` (abstract); `RoleMenu` (interface) |
| Polymorphism | `GradingService.autoGrade` calls `q.evaluate(...)` on every `Question`; `ExamInterface` calls `render`/`parseAnswer`/`formatAnswer`; `User.getRole()`, `getSearchText()`, `setRoleDetail()`; `ConsoleMenu` dispatches through `RoleMenu` |
| Encapsulation | Private fields everywhere; setters validate (`User.setUsername`, `Question.setPoints`, `Exam.setPassingPercentage` …); the password hash has no getter; collections are returned read-only |
| Collections | `HashMap` (username index, ID counters), `LinkedHashMap` (users, sessions, answers per question), `ArrayList` (questions, exams, results), `LinkedHashSet`/`TreeSet` (enrolment, selected choices), `EnumMap` (role → menu) |
| Exception handling | `try/catch` in every menu loop (`ScreenBase.execute`), input re-prompting in `InputReader`, custom exceptions in `src/exceptions` |
| File handling | `data/FileManager.java`, `data/DataStore.java` |
| Search and sorting | `UserService.search`, `ExamService.searchByTitle`, `QuestionBankService.searchByCategory`, `ReportService.filterResults`; `Comparator` constants `BY_NAME`, `BY_DATE`, `BY_TITLE`, `BY_SCORE_DESC`, `BY_DIFFICULTY` |

## How the timer works

1. When a student starts an attempt, the deadline is calculated **once**, as `min(start + duration, exam closing time)`, and saved to `sessions.dat` straight away.
2. Every save-answer and submit call checks the clock against that stored deadline. The on-screen countdown is only `deadline − now`, so it decides nothing.
3. A background thread (`ui.ExamTimer`) prints the 10, 5 and 1 minute warnings and asks the service to auto-submit once the deadline passes.
4. If the app closes during an exam, the attempt resumes with the same deadline. If the time ran out while the app was closed, the attempt is auto-submitted at start-up, stamped with the deadline, or marked *expired* if auto-submit is off.
5. Submissions are `synchronized` and checked by state, so the timer and the student can't both submit. A second submit raises `DuplicateSubmissionException`.

## Data files

Everything is saved in `data/` (`users.dat`, `subjects.dat`, `classes.dat`, `questions.dat`, `exams.dat`, `sessions.dat`, `results.dat`, `ids.dat`).

Each save writes a temporary file first and keeps the previous version as `*.bak`. If a file is unreadable, it is renamed to `*.corrupt-<time>` (never deleted) and the backup is loaded instead.

**Admin → Data management** shows record counts and any load warnings, and can make a full backup copy. Delete the `data/` folder to start over.

## Documentation

- [`docs/DESIGN.md`](docs/DESIGN.md): architecture, class design, timer and persistence strategy, task split, roadmap.
- [`docs/uml/class-diagram.md`](docs/uml/class-diagram.md): UML class diagrams (Mermaid; they display on GitHub).
- [`docs/TESTING.md`](docs/TESTING.md): test cases with the results that were actually recorded.
- [`docs/PRESENTATION.md`](docs/PRESENTATION.md): outline and demo script for the final presentation.

## Team

| Member | Area | Main files |
|---|---|---|
| Member 1 | Core OOP, users, authentication | `models/User*`, `Admin`, `Teacher`, `Student`, `Subject`, `SchoolClass`, `services/AuthenticationService`, `UserService`, `SubjectService`, `AccessControl`, `util/PasswordHasher`, `InputValidator`, `ui/AdminMenu`, `ConsoleMenu` |
| Member 2 | Questions, exams, timer, exam interface | `models/*Question`, `Exam`, `TimerSettings`, `ExamSession`, `StudentAnswer`, `services/QuestionBankService`, `ExamService`, `ExamSessionService`, `ui/TeacherMenu`, `QuestionForm`, `ExamInterface`, `ExamTimer` |
| Member 3 | Persistence, grading, reports, integration | `data/*`, `models/Result`, `QuestionScore`, `GradeOutcome`, `services/GradingService`, `ReportService`, `ServiceRegistry`, `ui/StudentMenu`, `ReportScreens`, `test/*` |
