const vscode = require('vscode');
const path = require('path');

/**
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
    const item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    item.text = '$(play) Run Jarvis';
    item.tooltip = 'Build and launch the Jarvis app';
    item.command = 'runJarvis.run';
    item.show();
    context.subscriptions.push(item);

    const disposable = vscode.commands.registerCommand('runJarvis.run', () => {
        const folders = vscode.workspace.workspaceFolders;
        if (!folders || folders.length === 0) {
            vscode.window.showErrorMessage('Please open the workspace containing Jarvis.');
            return;
        }
        const workspace = folders[0].uri.fsPath;
        const script = path.join(workspace, 'run_app.sh');
        const terminal = vscode.window.createTerminal({ name: 'Run Jarvis' });
        terminal.sendText(`cd "${workspace}" && ./run_app.sh`);
        terminal.show();
    });

    context.subscriptions.push(disposable);
}
exports.activate = activate;

function deactivate() {}
exports.deactivate = deactivate;
