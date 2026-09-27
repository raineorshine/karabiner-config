// Keeps macOS Dictation's input method (DictationIM) running, so the fn tap in karabiner.json never
// pays its cold launch. DictationIM quits itself when idle -- it calls terminate: on its own, so
// AppKit's NSDisableAutomaticTermination default does not stop it -- and the next tap then waits
// ~1.6s for launchd to spawn it. Its job is demand-launched on its Mach services, so one empty
// message to com.apple.DictationIM.startup brings it back; launchctl kickstart is refused under SIP,
// and open/AppleScript cannot launch it outside its launchd job. docs/system-shortcut-rules.md
//
// Loop: find DictationIM; if absent, poke it awake; otherwise block on a kqueue until it exits. No
// polling while it runs.
#include <libproc.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <stdio.h>
#include <string.h>
#include <sys/event.h>
#include <unistd.h>

static pid_t find_dictation(void) {
  pid_t pids[4096];
  int n = proc_listallpids(pids, sizeof pids);
  for (int i = 0; i < n; i++) {
    char name[64];
    if (proc_name(pids[i], name, sizeof name) > 0 && strcmp(name, "DictationIM") == 0) return pids[i];
  }
  return 0;
}

static void poke(void) {
  mach_port_t port;
  if (bootstrap_look_up(bootstrap_port, "com.apple.DictationIM.startup", &port) != KERN_SUCCESS) {
    fprintf(stderr, "dictation-warm: com.apple.DictationIM.startup not found\n");
    return;
  }
  mach_msg_header_t msg = {0};
  msg.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
  msg.msgh_size = sizeof msg;
  msg.msgh_remote_port = port;
  mach_msg(&msg, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof msg, 0, MACH_PORT_NULL, 1000, MACH_PORT_NULL);
  mach_port_deallocate(mach_task_self(), port);
}

int main(void) {
  int kq = kqueue();
  for (;;) {
    pid_t pid = find_dictation();
    if (!pid) {
      poke();
      // Back off: at most one poke every 5s, so a DictationIM that refuses to stay up costs nothing.
      sleep(5);
      continue;
    }
    struct kevent ev;
    EV_SET(&ev, pid, EVFILT_PROC, EV_ADD | EV_ONESHOT, NOTE_EXIT, 0, NULL);
    // Registering fails with ESRCH when the pid exited between the lookup and here: loop again.
    if (kevent(kq, &ev, 1, NULL, 0, NULL) == 0) kevent(kq, NULL, 0, &ev, 1, NULL);
    sleep(1);
  }
}
