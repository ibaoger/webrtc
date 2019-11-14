#!/usr/bin/env lucicfg

# Copyright (c) 2019 The WebRTC project authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# https://chromium.googlesource.com/infra/luci/luci-go/+/master/lucicfg/doc/

WEBRTC_GIT = "https://webrtc.googlesource.com/src"
WEBRTC_GERRIT = "https://webrtc-review.googlesource.com/src"

# Top-level configs:

lucicfg.config(
    config_dir = ".",
    tracked_files = [
        "commit-queue.cfg",
        "cr-buildbucket.cfg",
        "luci-logdog.cfg",
        "luci-milo.cfg",
        "luci-notify.cfg",
        "luci-notify/**/*",
        "luci-scheduler.cfg",
        "project.cfg",
    ],
)

luci.project(
    name = "webrtc",
    buildbucket = "cr-buildbucket.appspot.com",
    logdog = "luci-logdog.appspot.com",
    milo = "luci-milo.appspot.com",
    notify = "luci-notify.appspot.com",
    scheduler = "luci-scheduler.appspot.com",
    swarming = "chromium-swarm.appspot.com",
    acls = [
        acl.entry(
            [acl.BUILDBUCKET_READER, acl.LOGDOG_READER, acl.PROJECT_CONFIGS_READER, acl.SCHEDULER_READER],
            groups = ["all"],
        ),
        acl.entry(acl.LOGDOG_WRITER, groups = ["luci-logdog-chromium-writers"]),
        acl.entry(acl.SCHEDULER_OWNER, groups = ["project-webrtc-admins"]),
    ],
)

luci.logdog(
    gs_bucket = "chromium-luci-logdog",
)

luci.milo(
    logo = "https://storage.googleapis.com/chrome-infra/webrtc-logo-vert-retro-255x305.png",
)

luci.cq(
    status_host = "chromium-cq-status.appspot.com",
    submit_max_burst = 1,
    submit_burst_delay = 1 * time.minute,
)

luci.gitiles_poller(
    name = "webrtc-gitiles-trigger-master",
    bucket = "ci",
    repo = WEBRTC_GIT,
)

# Bucket definitions:

luci.bucket(
    name = "try",
    acls = [
        acl.entry(acl.BUILDBUCKET_TRIGGERER, groups = [
            "service-account-cq",
            "project-webrtc-tryjob-access",
        ]),
    ],
)

luci.bucket(
    name = "ci",
    acls = [
        acl.entry(acl.BUILDBUCKET_TRIGGERER, groups = [
            "project-webrtc-ci-schedulers",
        ], users = [
            "luci-scheduler@appspot.gserviceaccount.com",
        ]),
    ],
)

luci.bucket(
    name = "perf",
    acls = [
        acl.entry(acl.BUILDBUCKET_TRIGGERER, users = [
            "luci-scheduler@appspot.gserviceaccount.com",
            "webrtc-ci-builder@chops-service-accounts.iam.gserviceaccount.com",
        ]),
    ],
)

luci.bucket(
    name = "cron",
    acls = [
        acl.entry(acl.BUILDBUCKET_TRIGGERER, users = [
            "luci-scheduler@appspot.gserviceaccount.com",
        ]),
    ],
)

# Commit queue definitions:

luci.cq_group(
    name = "cq",
    tree_status_host = "webrtc-status.appspot.com",
    watch = [cq.refset(repo = WEBRTC_GERRIT, refs = ["refs/heads/master"])],
    acls = [
        acl.entry(acl.CQ_COMMITTER, groups = ["project-webrtc-committers"]),
        acl.entry(acl.CQ_DRY_RUNNER, groups = ["project-webrtc-tryjob-access"]),
    ],
    retry_config = cq.RETRY_ALL_FAILURES,
    cancel_stale_tryjobs = True,
)

luci.cq_group(
    name = "cq_branch",
    watch = [cq.refset(repo = WEBRTC_GERRIT, refs = ["refs/branch-heads/.+"])],
    acls = [
        acl.entry(acl.CQ_COMMITTER, groups = ["project-webrtc-committers"]),
        acl.entry(acl.CQ_DRY_RUNNER, groups = ["project-webrtc-tryjob-access"]),
    ],
    retry_config = cq.RETRY_ALL_FAILURES,
    cancel_stale_tryjobs = True,
)

luci.cq_group(
    name = "cq_infra",
    watch = [cq.refset(repo = WEBRTC_GERRIT, refs = ["refs/heads/infra/config"])],
    acls = [
        acl.entry(acl.CQ_COMMITTER, groups = ["project-webrtc-admins"]),
        acl.entry(acl.CQ_DRY_RUNNER, groups = ["project-webrtc-tryjob-access"]),
    ],
    retry_config = cq.RETRY_ALL_FAILURES,
    cancel_stale_tryjobs = True,
)

luci.cq_tryjob_verifier(
    builder = "presubmit",
    cq_group = "cq_infra",
)

luci.cq_tryjob_verifier(
    builder = "webrtc-internal:g3.webrtc-internal.try/internal_compile_lite",
    owner_whitelist = ["project-webrtc-internal-tryjob-access"],
    cq_group = "cq",
)

# Notifier definitions:

luci.notifier(
    name = "ci_notifier",
    on_failure = True,
    notify_emails = ["webrtc-sheriffs-robots@google.com"],
    template = luci.notifier_template(
        name = "ci",
        body = io.read_file("luci-notify/email-templates/ci.template"),
    ),
)

luci.notifier(
    name = "cron_notifier",
    on_failure = True,
    notify_emails = ["webrtc-troopers-robots@google.com"],
    template = luci.notifier_template(
        name = "cron",
        body = io.read_file("luci-notify/email-templates/cron.template"),
    ),
)

# Recipe definitions:

def recipe(recipe, pkg = "infra/recipe_bundles/chromium.googlesource.com/chromium/tools/build"):
    return luci.recipe(
        name = recipe.split("/")[-1],
        cipd_package = pkg,
        cipd_version = "refs/heads/master",
        recipe = recipe,
    )

recipe("chromium_trybot")
recipe("run_presubmit")
recipe("webrtc/auto_roll_webrtc_deps")
recipe("webrtc/ios")
recipe("webrtc/ios_api_framework")
recipe("webrtc/libfuzzer")
recipe("webrtc/more_configs")
recipe("webrtc/standalone")
recipe("lkgr_finder", pkg = "infra/recipe_bundles/chromium.googlesource.com/infra/infra")

# Console definitions:

luci.console_view(name = "ci", title = "Main", repo = WEBRTC_GIT, header = "console-header.textpb")
luci.console_view(name = "perf", title = "Perf", repo = WEBRTC_GIT, header = "console-header.textpb")
luci.list_view(name = "cron", title = "Cron")
luci.console_view(name = "fyi", title = "FYI", repo = WEBRTC_GIT, header = "console-header.textpb")
luci.list_view(name = "try", title = "Tryserver")

def add_milo(builder, views):
    """Add Milo console entries for the builder.

    Args:
      builder: builder name (str).
      views: dict where keys are names of consoles and values are either a
        category for the console (str, pipe-separated) or True, which means
        adding to a list view rather than a console.
    """
    for view_name, category in views.items():
        if category == None:
            continue
        elif type(category) == "string":
            category, _, short_name = category.rpartition("|")
            luci.console_view_entry(
                console_view = view_name,
                builder = builder,
                category = category or None,
                short_name = short_name or None,
            )
        elif category == True:
            luci.list_view_entry(
                list_view = view_name,
                builder = builder,
            )
        else:
            fail("Unexpected value for category: %r" % category)

lkgr_builders = {}

# Builder-defining functions:

def webrtc_builder(
        name,
        recipe = "standalone",
        dimensions = {},
        priority = 30,
        execution_timeout = 2 * time.hour,
        **kwargs):
    dimensions = merge_dicts({"cpu": "x86-64"}, dimensions)

    return luci.builder(
        name = name,
        executable = recipe,
        dimensions = {k: v for k, v in dimensions.items() if v != None},
        execution_timeout = execution_timeout,
        priority = priority,
        build_numbers = True,
        swarming_tags = ["vpython:native-python-wrapper"],
        **kwargs
    )

def ci_builder(
        name,
        ci_cat,
        perf_cat = None,
        fyi_cat = None,
        properties = {},
        dimensions = {},
        prioritized = False,
        enabled = True,
        **kwargs):
    """Add a post-submit builder.

    Args:
      name: builder name (str).
      ci_cat: the category + name for the /ci/ console, or None to omit from the console.
      perf_cat: the category + name for the /perf/ console, or None to omit from the console.
      fyi_cat: the category + name for the /fyi/ console, or None to omit from the console.
      properties: dict of properties to pass to the recipe (on top of the default ones).
      dimensions: dict of Swarming dimensions (strings) to search machines by.
      prioritized: True to make this builder have a higher priority and never batch builds.
      enabled: False to exclude this builder from consoles and failure notifications.
      **kwargs: Pass on to webrtc_builder / luci.builder.
    Returns:
      A luci.builder.

    Notifications are also disabled if a builder is not on either of /ci/ or /perf/ consoles.
    """
    if prioritized:
        kwargs["triggering_policy"] = scheduler.greedy_batching(
            max_batch_size = 1,
            max_concurrent_invocations = 3,
        )
        kwargs["priority"] = 29

    if enabled:
        add_milo(name, {"ci": ci_cat, "perf": perf_cat, "fyi": fyi_cat})
        if ci_cat:
            lkgr_builders[name] = True
    return webrtc_builder(
        name = name,
        properties = merge_dicts({"mastername": "client.webrtc"}, properties),
        dimensions = merge_dicts({"pool": "luci.webrtc.ci"}, dimensions),
        bucket = "ci",
        service_account = "webrtc-ci-builder@chops-service-accounts.iam.gserviceaccount.com",
        triggered_by = ["webrtc-gitiles-trigger-master"] if enabled else None,
        repo = WEBRTC_GIT,
        notifies = ["ci_notifier"] if enabled and (ci_cat or perf_cat) else None,
        **kwargs
    )

def try_builder(
        name,
        try_cat = True,
        fyi_cat = None,
        properties = {},
        dimensions = {},
        cq = {},
        branch_cq = True,
        **kwargs):
    """Add a pre-submit builder.

    Args:
      name: builder name (str).
      try_cat: boolean, whether to include this builder in the /try/ console. See also: `add_milo`.
      fyi_cat: the category + name for the /fyi/ console, or None to omit from the console.
      properties: dict of properties to pass to the recipe (on top of the default ones).
      dimensions: dict of Swarming dimensions (strings) to search machines by.
      cq: None to exclude this from all commit queues, or a dict of kwargs for cq_tryjob_verifier.
      branch_cq: False to exclude this builder just from the release-branch CQ.
      **kwargs: Pass on to webrtc_builder / luci.builder.
    Returns:
      A luci.builder.
    """
    add_milo(name, {"try": try_cat, "fyi": fyi_cat})
    if cq != None:
        luci.cq_tryjob_verifier(
            builder = name,
            cq_group = "cq",
            **cq
        )
        if branch_cq:
            luci.cq_tryjob_verifier(
                builder = name,
                cq_group = "cq_branch",
                **cq
            )

    return webrtc_builder(
        name = name,
        properties = merge_dicts({"mastername": "tryserver.webrtc"}, properties),
        dimensions = merge_dicts({"pool": "luci.webrtc.try"}, dimensions),
        bucket = "try",
        service_account = "webrtc-try-builder@chops-service-accounts.iam.gserviceaccount.com",
        **kwargs
    )

def perf_builder(
        name,
        perf_cat,
        recipe = "standalone",
        properties = {},
        dimensions = {},
        **kwargs):
    add_milo(name, {"perf": perf_cat})
    return webrtc_builder(
        name = name,
        recipe = recipe,
        properties = merge_dicts({"mastername": "client.webrtc.perf"}, properties),
        dimensions = merge_dicts({"pool": "luci.webrtc.perf", "os": "Linux", "cpu": None}, dimensions),
        bucket = "perf",
        service_account = "webrtc-ci-builder@chops-service-accounts.iam.gserviceaccount.com",
        # log_base of 1.7 means:
        # when there are P pending builds, LUCI will batch the first B builds.
        # P:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 ...
        # B:  1  1  2  2  3  3  3  3  4  4  4  4  4  4  5 ...
        triggering_policy = scheduler.logarithmic_batching(log_base = 17 / 10),
        execution_timeout = 3 * time.hour,
        **kwargs
    )

def cron_builder(name, dimensions = {}, **kwargs):
    add_milo(name, {"cron": True})
    return webrtc_builder(
        name = name,
        dimensions = merge_dicts({"pool": "luci.webrtc.cron", "os": "Linux"}, dimensions),
        bucket = "cron",
        service_account = "chromium-webrtc-autoroll@webrtc-ci.iam.gserviceaccount.com",
        repo = WEBRTC_GIT,
        notifies = ["cron_notifier"],
        **kwargs
    )

# Helpers:

def merge_dicts(a, b):
    """Return the result of merging two dicts.

    If matching values are both dicts or both lists, they will be merged (non-recursively).

    Args:
      a: first dict.
      b: second dict (takes priority).
    Returns:
      Merged dict.
    """
    a = dict(a)
    for k, bv in b.items():
        av = a.get(k)
        if type(av) == "dict" and type(bv) == "dict":
            a[k] = dict(av)
            a[k].update(bv)
        elif type(av) == "list" and type(bv) == "list":
            a[k] = av + bv
        else:
            a[k] = bv
    return a

def normal_builder_factory(**common_kwargs):
    def builder(*args, **kwargs):
        return ci_builder(*args, **merge_dicts(common_kwargs, kwargs))

    def try_job(*args, **kwargs):
        return try_builder(*args, **merge_dicts(common_kwargs, kwargs))

    return builder, try_job

# Mixins:

linux_builder, linux_try_job = normal_builder_factory(
    dimensions = {"os": "Linux", "inside_docker": "0"},
)

android_builder, android_try_job = normal_builder_factory(
    dimensions = {"os": "Linux"},
)

win_builder, win_try_job = normal_builder_factory(
    dimensions = {"os": "Windows"},
)

mac_builder, mac_try_job = normal_builder_factory(
    dimensions = {"os": "Mac"},
)

ios_builder, ios_try_job = normal_builder_factory(
    dimensions = {"os": "Mac-10.13"},
    recipe = "ios",
    properties = {"$depot_tools/osx_sdk": {"sdk_version": "10l232m"}},
    caches = [swarming.cache("osx_sdk")],
)

# Actual builder configuration:

android_builder("Android32 (M Nexus5X)(dbg)", "Android|arm|dbg")
android_try_job("android_compile_arm_dbg", cq = None)
android_try_job("android_arm_dbg")
android_builder("Android32 (M Nexus5X)", "Android|arm|rel")
android_try_job("android_arm_rel")
android_builder("Android32 Builder arm", "Android|arm|size", perf_cat = "Android|arm|Builder|", prioritized = True)
android_try_job("android_compile_arm_rel")
perf_builder("Perf Android32 (L Nexus4)", "Android|arm|Tester|L Nexus4", triggered_by = ["Android32 Builder arm"])
perf_builder("Perf Android32 (K Nexus5)", "Android|arm|Tester|K Nexus5", triggered_by = ["Android32 Builder arm"])
perf_builder("Perf Android32 (L Nexus5)", "Android|arm|Tester|L Nexus5", triggered_by = ["Android32 Builder arm"])
perf_builder("Perf Android32 (L Nexus6)", "Android|arm|Tester|L Nexus6", triggered_by = ["Android32 Builder arm"])
perf_builder("Perf Android32 (L Nexus7.2)", "Android|arm|Tester|L Nexus7.2", triggered_by = ["Android32 Builder arm"])
perf_builder("Perf Android32 (N Nexus6)", "Android|arm|Tester|N Nexus6", triggered_by = ["Android32 Builder arm"])
android_builder("Android64 (M Nexus5X)(dbg)", "Android|arm64|dbg")
android_try_job("android_compile_arm64_dbg", cq = None)
android_try_job("android_arm64_dbg", cq = None)
android_builder("Android64 (M Nexus5X)", "Android|arm64|rel")
android_try_job("android_arm64_rel")
android_builder("Android64 Builder arm64", "Android|arm64|size", perf_cat = "Android|arm64|Builder|", prioritized = True)
android_try_job("android_compile_arm64_rel")
perf_builder("Perf Android64 (L Nexus9)", "Android|arm64|Tester|L Nexus9", triggered_by = ["Android64 Builder arm64"])
perf_builder("Perf Android64 (N Pixel)", "Android|arm64|Tester|N Pixel", triggered_by = ["Android64 Builder arm64"])
android_builder("Android64 Builder x64 (dbg)", "Android|x64|dbg")
android_try_job("android_compile_x64_dbg")
android_try_job("android_compile_x64_rel", cq = None)
android_builder("Android32 Builder x86 (dbg)", "Android|x86|dbg")
android_try_job("android_compile_x86_dbg")
android_builder("Android32 Builder x86", "Android|x86|rel")
android_try_job("android_compile_x86_rel")
android_builder("Android32 (more configs)", "Android|arm|more", recipe = "more_configs")
android_try_job("android_arm_more_configs", recipe = "more_configs")
android_try_job("android_chromium_compile", recipe = "chromium_trybot", branch_cq = False)

ios_builder("iOS32 Debug", "iOS|arm|dbg")
ios_try_job("ios_compile_arm_dbg")
ios_builder("iOS32 Release", "iOS|arm|rel")
ios_try_job("ios_compile_arm_rel")
ios_builder("iOS64 Debug", "iOS|arm64|dbg")
ios_try_job("ios_compile_arm64_dbg")
ios_builder("iOS64 Release", "iOS|arm64|rel")
ios_try_job("ios_compile_arm64_rel")
ios_builder("iOS64 Sim Debug (iOS 10.0)", "iOS|x64|10")
ios_try_job("ios_sim_x64_dbg_ios10")
ios_builder("iOS64 Sim Debug (iOS 11)", "iOS|x64|11")
ios_try_job("ios_sim_x64_dbg_ios11")
ios_builder("iOS64 Sim Debug (iOS 12)", "iOS|x64|12")
ios_try_job("ios_sim_x64_dbg_ios12")
ios_builder("iOS API Framework Builder", "iOS|fat|size", recipe = "ios_api_framework", prioritized = True)
ios_try_job("ios_api_framework", recipe = "ios_api_framework")

linux_builder("Linux32 Debug", "Linux|x86|dbg")
linux_try_job("linux_x86_dbg")
linux_builder("Linux32 Release", "Linux|x86|rel")
linux_try_job("linux_x86_rel")
linux_builder("Linux64 Debug", "Linux|x64|dbg")
linux_try_job("linux_dbg", cq = None)
linux_try_job("linux_compile_dbg")
linux_builder("Linux64 Release", "Linux|x64|rel")
linux_try_job("linux_rel")
linux_builder("Linux64 Builder", "Linux|x64|size", perf_cat = "Linux|x64|Builder|", prioritized = True)
linux_try_job("linux_compile_rel")
perf_builder("Perf Linux Trusty", "Linux|x64|Tester|Trusty", triggered_by = ["Linux64 Builder"])
perf_builder("Perf Linux Xenial", None, triggered_by = ["Linux64 Builder"])
linux_builder("Linux32 Debug (ARM)", "Linux|arm|dbg")
linux_try_job("linux_compile_arm_dbg")
linux_builder("Linux32 Release (ARM)", "Linux|arm|rel")
linux_try_job("linux_compile_arm_rel")
linux_builder("Linux64 Debug (ARM)", "Linux|arm64|dbg")
linux_try_job("linux_compile_arm64_dbg")
linux_builder("Linux64 Release (ARM)", "Linux|arm64|rel")
linux_try_job("linux_compile_arm64_rel")
linux_builder("Linux64 Release (GCC)", "Linux|x64|gcc")
linux_try_job("linux_compile_gcc_rel")
linux_builder("Linux Asan", "Linux|x64|asan")
linux_try_job("linux_asan")
linux_builder("Linux MSan", "Linux|x64|msan")
linux_try_job("linux_msan")
linux_builder("Linux Tsan v2", "Linux|x64|tsan")
linux_try_job("linux_tsan2")
linux_builder("Linux UBSan", "Linux|x64|ubsan")
linux_try_job("linux_ubsan")
linux_builder("Linux UBSan vptr", "Linux|x64|ubsan")
linux_try_job("linux_ubsan_vptr")
linux_builder("Linux64 Release (Libfuzzer)", "Linux|x64|fuzz", recipe = "libfuzzer")
linux_try_job("linux_libfuzzer_rel", recipe = "libfuzzer")
linux_builder("Linux (more configs)", "Linux|x64|more", recipe = "more_configs")
linux_try_job("linux_more_configs", recipe = "more_configs")
linux_try_job("linux_chromium_compile", recipe = "chromium_trybot", branch_cq = False)
linux_try_job("linux_chromium_compile_dbg", cq = None, recipe = "chromium_trybot", branch_cq = False)

mac_builder("Mac64 Debug", "Mac|x64|dbg")
mac_try_job("mac_dbg", cq = None)
mac_try_job("mac_compile_dbg")
mac_builder("Mac64 Release", "Mac|x64|rel")
mac_try_job("mac_rel")
mac_try_job("mac_compile_rel", cq = None)
mac_builder("Mac64 Builder", ci_cat = None, perf_cat = "Mac|x64|Builder|")
perf_builder("Perf Mac 10.11", "Mac|x64|Tester|10.11", triggered_by = ["Mac64 Builder"])
mac_builder("Mac Asan", "Mac|x64|asan")
mac_try_job("mac_asan")
mac_try_job("mac_chromium_compile", recipe = "chromium_trybot", dimensions = {"cores": "8"}, branch_cq = False)

win_builder("Win32 Debug", "Win MSVC|x86|dbg")
win_try_job("win_x86_msvc_dbg")
win_try_job("win_compile_x86_msvc_dbg", cq = None)
win_builder("Win32 Release", "Win MSVC|x86|rel")
win_try_job("win_x86_msvc_rel")
win_try_job("win_compile_x86_msvc_rel", cq = None)
win_builder("Win64 Debug", "Win MSVC|x64|dbg")
win_try_job("win_x64_msvc_dbg")
win_try_job("win_compile_x64_msvc_dbg", cq = None)
win_builder("Win64 Release", "Win MSVC|x64|rel")
win_try_job("win_x64_msvc_rel")
win_try_job("win_compile_x64_msvc_rel", cq = None)
win_builder("Win32 Debug (Clang)", "Win Clang|x86|dbg")
win_try_job("win_x86_clang_dbg", cq = None)
win_try_job("win_compile_x86_clang_dbg")
win_builder("Win32 Release (Clang)", "Win Clang|x86|rel")
win_try_job("win_x86_clang_rel")
win_try_job("win_compile_x86_clang_rel", cq = None)
win_builder("Win32 Builder (Clang)", ci_cat = None, perf_cat = "Win|x86|Builder|")
perf_builder("Perf Win7", "Win|x86|Tester|7", triggered_by = ["Win32 Builder (Clang)"])
win_builder("Win64 Debug (Clang)", "Win Clang|x64|dbg")
win_try_job("win_x64_clang_dbg", cq = None)
win_try_job("win_x64_clang_dbg_win8", cq = None)
win_try_job("win_x64_clang_dbg_win10", cq = None)
win_try_job("win_compile_x64_clang_dbg")
win_builder("Win64 Release (Clang)", "Win Clang|x64|rel")
win_try_job("win_x64_clang_rel", cq = None)
win_try_job("win_compile_x64_clang_rel")
win_builder("Win64 ASan", "Win Clang|x64|asan")
win_try_job("win_asan")
win_builder("Win64 UWP", ci_cat = None, fyi_cat = "")
win_try_job("win_x64_uwp", cq = None, try_cat = None, fyi_cat = "")
win_builder("Win (more configs)", "Win Clang|x86|more", recipe = "more_configs")
win_try_job("win_x86_more_configs", recipe = "more_configs")
win_try_job("win_chromium_compile", recipe = "chromium_trybot", branch_cq = False)
win_try_job("win_chromium_compile_dbg", cq = None, recipe = "chromium_trybot", branch_cq = False)

linux_try_job(
    "presubmit",
    recipe = "run_presubmit",
    properties = {"repo_name": "webrtc", "runhooks": True},
    priority = 28,
    cq = {"disable_reuse": True},
)

cron_builder(
    "Auto-roll - WebRTC DEPS",
    recipe = "auto_roll_webrtc_deps",
    schedule = "0 */2 * * *",  # Every 2 hours.
)

lkgr_config = {
    "project": "webrtc",
    "source_url": WEBRTC_GIT,
    "status_url": "https://webrtc-status.appspot.com",
    "allowed_lag": 300,  # hours
    "allowed_gap": 12,  # commits behind
    "error_recipients": "webrtc-troopers-robots@google.com",
    "buckets": {
        "webrtc/ci": {
            # bucket alias: luci.webrtc.ci
            "builders": sorted(lkgr_builders),
        },
        "chromium/webrtc.fyi": {
            # bucket alias: luci.chromium.webrtc.fyi
            "builders": [
                "WebRTC Chromium FYI Android Builder (dbg)",
                "WebRTC Chromium FYI Android Builder ARM64 (dbg)",
                "WebRTC Chromium FYI Android Builder",
                "WebRTC Chromium FYI Android Tests (dbg) (K Nexus5)",
                "WebRTC Chromium FYI Android Tests (dbg) (M Nexus5X)",
                "WebRTC Chromium FYI Linux Builder (dbg)",
                "WebRTC Chromium FYI Linux Builder",
                "WebRTC Chromium FYI Linux Tester",
                "WebRTC Chromium FYI Mac Builder (dbg)",
                "WebRTC Chromium FYI Mac Builder",
                "WebRTC Chromium FYI Mac Tester",
                "WebRTC Chromium FYI Win Builder (dbg)",
                "WebRTC Chromium FYI Win Builder",
                "WebRTC Chromium FYI Win10 Tester",
                "WebRTC Chromium FYI Win7 Tester",
                "WebRTC Chromium FYI Win8 Tester",
                "WebRTC Chromium FYI ios-device",
                "WebRTC Chromium FYI ios-simulator",
            ],
        },
    },
}

cron_builder(
    "WebRTC lkgr finder",
    recipe = "lkgr_finder",
    properties = {
        "project": "webrtc",
        "repo": WEBRTC_GIT,
        "ref": "refs/heads/lkgr",
        "lkgr_status_gs_path": "chromium-webrtc/lkgr-status",
        "config": lkgr_config,
    },
    schedule = "*/10 * * * *",  # Every 10 minutes.
)
