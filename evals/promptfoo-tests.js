// Dynamic test generation for the promptfoo runner.
//
// Reads the SAME trigger-evals.json the Python runner uses, so the two runners
// can never drift apart on the query set. Add or edit queries there, not here.

const fs = require('fs');
const path = require('path');

module.exports = function () {
  const spec = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'trigger-evals.json'), 'utf8')
  );

  // opencode:sdk:<suffix> identifies a provider *instance* (the suffix does not
  // select a model). Each instance carries a different working_dir, which is how
  // a query is run inside a spec-kit repo or a plain one.
  const instanceFor = (context) =>
    context === 'spec-kit' ? 'opencode:sdk:spec-kit' : 'opencode:sdk:plain';

  const tests = [];

  for (const q of spec.should_trigger) {
    tests.push({
      description: `${q.id} SHOULD trigger`,
      vars: { query: q.query },
      options: { provider: instanceFor(q.context) },
      assert: [{ type: 'skill-used', value: spec.skill }],
    });
  }

  for (const q of spec.should_not_trigger) {
    tests.push({
      description: `${q.id} should NOT trigger - ${q.why}`,
      vars: { query: q.query },
      options: { provider: instanceFor(q.context) },
      // Every promptfoo assertion can be negated by prepending `not-`.
      assert: [{ type: 'not-skill-used', value: spec.skill }],
    });
  }

  return tests;
};
