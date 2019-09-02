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
-- Copyright (C) 2015 - 2019, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        target.lua
--

-- imports
import("core.base.option")
import("core.base.hashset")
import("core.theme.theme")
import("core.tool.compiler")
import("core.project.depend")

-- build the source files
function main(target, sourcebatch, opt)

    -- is verbose?
    local verbose = option.get("verbose")

    -- get progress range
    local progress = assert(opt.progress, "no progress!")

    -- get source files and kind
    local sourcefiles = sourcebatch.sourcefiles
    local sourcekind  = sourcebatch.sourcekind

    -- get object file
    local objectfile = target:objectfile(path.join(path.directory(sourcefiles[1]), "__go__"))

    -- get depend file
    local dependfile = target:dependfile(objectfile)

    -- remove the object files in sourcebatch
    local objectfiles_set = hashset.from(sourcebatch.objectfiles)
    for idx, file in irpairs(target:objectfiles()) do
        if objectfiles_set:has(file) then
            table.remove(target:objectfiles(), idx)
        end
    end

    -- add object file
    table.insert(target:objectfiles(), objectfile)

    -- load compiler 
    local compinst = compiler.load(sourcekind, {target = target})

    -- get compile flags
    local compflags = compinst:compflags({target = target})

    -- load dependent info 
    local dependinfo = option.get("rebuild") and {} or (depend.load(dependfile) or {})
    
    -- need build this object?
    local depvalues = {compinst:program(), compflags}
    if not depend.is_changed(dependinfo, {lastmtime = os.mtime(objectfile), values = depvalues}) then
        return 
    end

    -- trace progress info
    for index, sourcefile in ipairs(sourcefiles) do

        -- calculate progress
        local progress_now = progress.start + ((index - 1) * (progress.stop - progress.start)) / #sourcefiles

        -- trace progress info
        cprintf("${color.build.progress}" .. theme.get("text.build.progress_format") .. ":${clear} ", progress_now)
        if verbose then
            cprint("${dim color.build.object}compiling.$(mode) %s", sourcefile)
        else
            cprint("${color.build.object}compiling.$(mode) %s", sourcefile)
        end
    end

    -- trace verbose info
    if verbose then
        print(compinst:compcmd(sourcefiles, objectfile, {compflags = compflags}))
    end

    -- flush io buffer to update progress info
    io.flush()

    -- compile it 
    dependinfo.files = {}
    assert(compinst:compile(sourcefiles, objectfile, {dependinfo = dependinfo, compflags = compflags}))

    -- update files and values to the dependent file
    dependinfo.values = depvalues
    table.join2(dependinfo.files, sourcefiles)
    depend.save(dependinfo, dependfile)
end
