You are running unattended as work item {{ITEM}} of the work queue at {{WORK_DIR}}.
Nobody is watching and nobody can answer a question, so make reasonable
decisions yourself and finish the task. Do not ask for confirmation.

Earlier items in this queue left their output under {{WORK_DIR}}/.run/<item>/
(response.md is a model's final message, output.log is a script's output).
Anything you want a later item to find belongs in {{RUN_DIR}} unless the
task names another place.

End with a short summary of what you did and anything the next item should know.
