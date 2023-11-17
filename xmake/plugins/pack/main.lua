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
-- Copyright (C) 2015-present, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        main.lua
--

-- imports
import("core.base.task")
import("core.base.option")
import("core.project.project")
import("private.service.remote_build.action", {alias = "remote_build_action"})
import("actions.build.main", {rootdir = os.programdir(), alias = "build_action"})
import("xpack")

function _load_package(package, format)
    package:format_set(format)
    local script = package:script("load")
    if script then
        script(package)
    end
end

function _on_package(package)
    import(package:format())(package)
end

function _pack_package(package)

    -- ensure build and output directories
    os.tryrm(package:buildir())
    os.mkdir(package:outputdir())

    -- get need formats
    local formats_need = option.get("formats")
    if formats_need then
        formats_need = formats_need:split(",")
        if formats_need[1] == "all" then
            formats_need = nil
        end
    end

    -- do pack
    assert(package:formats(), "xpack(%s): formats not found, please use `set_formats()` to set it.", package:name())
    local scripts = {
        package:script("package_before"),
        package:script("package", _on_package),
        package:script("package_after")
    }
    for _, format in package:formats():keys() do
        if not formats_need or table.contains(formats_need, format) then
            _load_package(package, format)
            for i = 1, 3 do
                local script = scripts[i]
                if script ~= nil then
                    script(package)
                end
            end
        end
    end
end

function _pack_packages()
    for _, package in pairs(xpack.packages()) do
        _pack_package(package)
    end
end

function _build_targets()
    local targetnames = {}
    for _, package in pairs(xpack.packages()) do
        local targets = package:get("targets")
        if targets then
            table.join2(targetnames, targets)
        end
    end
    if #targetnames > 0 then
        build_action.build_targets(targetnames)
    end
end

function main()

    -- do action for remote?
    if remote_build_action.enabled() then
        return remote_build_action()
    end

    -- lock the whole project
    project.lock()

    -- load config first
    task.run("config", {}, {disable_dump = true})

    -- load targets
    project.load_targets()

    -- enter project directory
    local oldir = os.cd(project.directory())

    -- build targets first
    if option.get("autobuild") then
        _build_targets()
    end

    -- do pack
    _pack_packages()

    -- leave project directory
    os.cd(oldir)

    -- unlock the whole project
    project.unlock()
    cprint("${color.success}pack ok")
end


