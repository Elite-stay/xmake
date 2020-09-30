--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015-2020, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        uninstall.lua
--

-- imports
import("core.base.task")
import("core.project.rule")
import("core.project.project")
import("target.action.uninstall", {alias = "_do_uninstall_target"})

-- on uninstall target
function _on_uninstall_target(target)

    -- trace
    print("uninstalling %s ..", target:name())

    -- build target with rules
    local done = false
    for _, r in ipairs(target:orderules()) do
        local on_uninstall = r:script("uninstall")
        if on_uninstall then
            on_uninstall(target)
            done = true
        end
    end
    if done then return end

    -- do uninstall
    _do_uninstall_target(target)
end

-- uninstall the given target
function _uninstall_target(target)

    -- has been disabled?
    if target:get("enabled") == false then
        return
    end

    -- enter project directory
    local oldir = os.cd(project.directory())

    -- enter the environments of the target packages
    local oldenvs = {}
    for name, values in pairs(target:pkgenvs()) do
        oldenvs[name] = os.getenv(name)
        os.addenv(name, unpack(values))
    end

    -- the target scripts
    local scripts =
    {
        target:script("uninstall_before")
    ,   function (target)
            for _, r in ipairs(target:orderules()) do
                local before_uninstall = r:script("uninstall_before")
                if before_uninstall then
                    before_uninstall(target)
                end
            end
        end
    ,   target:script("uninstall", _on_uninstall_target)
    ,   function (target)
            for _, r in ipairs(target:orderules()) do
                local after_uninstall = r:script("uninstall_after")
                if after_uninstall then
                    after_uninstall(target)
                end
            end
        end
    ,   target:script("uninstall_after")
    }

    -- uninstall the target scripts
    for i = 1, 5 do
        local script = scripts[i]
        if script ~= nil then
            script(target)
        end
    end

    -- leave the environments of the target packages
    for name, values in pairs(oldenvs) do
        os.setenv(name, values)
    end

    -- leave project directory
    os.cd(oldir)
end

-- uninstall the given target and deps
function _uninstall_target_and_deps(target)

    -- this target have been finished?
    if _g.finished[target:name()] then
        return
    end

    -- uninstall for all dependent targets
    for _, depname in ipairs(target:get("deps")) do
        _uninstall_target_and_deps(project.target(depname))
    end

    -- uninstall target
    _uninstall_target(target)

    -- finished
    _g.finished[target:name()] = true
end

-- uninstall
function main(targetname)

    -- init finished states
    _g.finished = {}

    -- uninstall given target?
    if targetname then
        _uninstall_target_and_deps(project.target(targetname))
    else
        -- uninstall all targets
        for _, target in pairs(project.targets()) do
            _uninstall_target_and_deps(target)
        end
    end
end
