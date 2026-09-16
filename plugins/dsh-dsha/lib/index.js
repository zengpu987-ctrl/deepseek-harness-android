import { spawn } from 'node:child_process'

export const name = 'dsh-dsha'
export const inject = ['commands']

const SCRCPY = '/Users/zp/bin/scrcpy'

export function apply(ctx) {
  ctx.commands.register({
    name: 'dsha',
    description: '远程控制安卓手机：打开 DSHA 实时画面窗口',
    handler: () => {
      const child = spawn(SCRCPY, ['--window-title', 'DSHA', '--stay-awake'], {
        detached: true,
        stdio: 'ignore',
      })
      child.on('error', (error) => {
        // Handled by the child process; keep the command non-blocking.
        void error
      })
      child.unref()
      return {
        kind: 'success',
        text: '已打开 DSHA 远控窗口，可实时查看并用鼠标/键盘操作手机。',
      }
    },
  })
}
