# Trai Workout Plan Evaluation Harness

A lightweight, developer-friendly validation playground designed for **Trai builders** to systematically review, score, and audit AI-generated workout plans against complex user briefs.

## Problem Context
AI agents are excellent at generating tailored workout programs, but validation is challenging. Builders need an instant, visual feedback loop to verify if generated workouts successfully avoid medical contraindications, follow appropriate progressive overload schemes, respect available equipment constraints, and target the correct user demographics.

## Features
- **Interactive Input Editor**: Tweak user briefs (injury rules, goals, age) and the generated program structure live.
- **Automated Rule Validation**: Instant rule-based checks matching constraints (e.g., verifying if an injury-avoided movement snuck into the AI's generated plan).
- **Manual Quality Calibration**: Drag sliders to score safety, target fit, progression logic, and constraints.
- **Pre-loaded Templates**: Instantly toggle between a well-behaved "Knee Rehab" safety-compliant plan and a faulty "Hypertrophy Push" plan that violates injury rules.
- **JSON Quality Export**: Export a completed rating scheme in standard format to extend prompt-tuning datasets or prompt engineering.

## Setup & Running the Prototype

To launch this evaluation harness locally:

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Start the development server**:
   ```bash
   npm run dev
   ```

3. **Verify the App**:
   Open the browser at the local address (typically `http://localhost:5173`) to interact with the evaluator.

## File Structure
- `package.json` - Declares React and Vite development dependencies.
- `index.html` - Mount point with Tailwind CSS loaded for responsive layouts.
- `src/main.jsx` - React boilerplate.
- `src/App.jsx` - Core component containing state, rule checks, scorecard sliders, and templates.