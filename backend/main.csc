import codec.base64.standard as base64
import csdbc_mysql as mysql
import codec.json as json
import process

# Settings, please fill before using
var backend_path = ""
var workspace_path = ""
var conn_str = "Driver={" + backend_path + "/libmaodbc.so};SERVER=localhost;USER=;PASSWORD=;DATABASE=;PORT=3306"

var enable_log = true
var stdlog = iostream.fstream(backend_path + "/main.log", iostream.openmode.app)

function time_padding(obj, width)
    var time = to_string(obj)
    var last = width - time.size
    if last <= 0
        return time
    end
    var str = new string
    foreach it in range(last) do str += "0"
    return str + time
end

function log(msg)
    if enable_log
        var tm = runtime.local_time()
        stdlog.print("[" + time_padding(tm.year + 1900, 4) + "." + time_padding(tm.mon + 1, 2) + "." + time_padding(tm.mday, 2) + " " + time_padding(tm.hour, 2) + ":" + time_padding(tm.min, 2) + ":" + time_padding(tm.sec, 2) + "]: ")
        stdlog.println(msg)
    end
end

# Expires time(second)
var expire_time = 600

function get_time()
    var tm = runtime.utc_time()
    return {"year": tm.year, "yday": tm.yday, "hour": tm.hour, "min": tm.min, "sec": tm.sec}.to_hash_map()
end

function time2str(tm)
    return json.to_string(json.from_var(tm))
end

function record_expired(timestamp)
    var ts = json.to_var(json.from_string(timestamp))
    var cur = get_time()
    if ts.year != cur.year
        return true
    end
    if cur.yday - ts.yday > 1
        return true
    end
    if cur.yday > ts.yday
        cur.hour += 24
    end
    var diff = (cur.hour - ts.hour)*3600 + (cur.min - ts.min)*60 + (cur.sec - ts.sec)
    return diff > expire_time
end

function get_timestr()
    var str = to_string(runtime.utc_time())
    str.cut(1)
    return move(str)
end

function get_image_blob(db, sql)
    var r = db.db.exec(sql)
    if !r.done()
        return r.get(0)
    else
        return null
    end
end

function print_welcome()
    system.out.println("<p>Welcome to [Application Name] Server!</p>")
    system.out.println("<p>This is backend executor of Server, please visit <a href=\"/index.html\">main page</a>.</p>")
    system.out.println("<p>Backend executor is powered by <a href=\"https://unicov.cn/covscript/\">Covariant Script</a>.</p>")
    system.out.println("<p>Copyright (C) [Name] [Year]</p>")
end

if context.cmd_args.size == 1
    print_welcome()
    system.exit(0)
end

# CREATE TABLE INSTANCE(ID VARCHAR(255), STATE VARCHAR(255), DATA TEXT, TIME VARCHAR(255))
# CREATE TABLE RESULT(ID VARCHAR(255), DATA LONGTEXT)
var db = mysql.connect_str(conn_str)

function retiring_records()
    var data = db.exec("SELECT ID, STATE, TIME FROM INSTANCE")
    foreach it in data
        it[2].data = base64.decode(it[2].data)
    end
    foreach it in data
        if it[1].data != "PREPARE" && record_expired(it[2].data)
            if it[1].data == "WORKING"
                process.exec("docker", {"stop", "-t", "0", it[0].data}).wait()
            end
            log("Retiring instance " + it[0].data + " by expires time " + expire_time + "s")
            db.just_exec("DELETE FROM INSTANCE WHERE ID=\"" + it[0].data + "\"")
            db.just_exec("DELETE FROM RESULT WHERE ID=\"" + it[0].data + "\"")
        end
    end
end

function get_post_body()
    return json.to_var(json.from_stream(system.in))
end

@begin
var state_map = {
    "PREPARE":"Booting...",
    "WORKING":"Working...",
    "DONE":"Done"
}.to_hash_map()
@end

log("Receiving new request, method = " + context.cmd_args[1])

switch context.cmd_args[1]
    default
        system.out.println("<p>ERROR! Non-exist parameter.")
        print_welcome()
    end
    case "submit"
        # Booting new instance
        var body = get_post_body()
        var p = process.exec("docker", ("run -it -d --rm -v " + workspace_path + ":/workspace/upload image:tag").split({' '}))
        p.wait()
        var id = p.out().getline()
        var stmt = db.prepare("INSERT INTO INSTANCE VALUES(?,?,?,?)")
        stmt.bind(0, id)
        stmt.bind(1, "PREPARE")
        stmt.bind(2, base64.encode(json.to_string(json.from_var(body))))
        stmt.bind(3, base64.encode(time2str(get_time())))
        stmt.just_exec()
        system.out.print(id)
        process.exec("cs", {backend_path + "/queue.csc", "INSTANCE", "10", base64.encode(backend_path + "/driver.csc " + id)})
    end
    case "queueing"
        # Get queueing list
        var data = db.exec("SELECT ID, STATE FROM INSTANCE")
        if data.empty()
            system.out.print("[{\"id\":\"NULL\", \"state\": \"NULL\"}]")
        else
            var str = "["
            foreach it in data
                str += "[\"" + it[0].data + "\", \"" + state_map[it[1].data] + "\"], "
            end
            str.cut(2)
            str += "]"
            system.out.print(str)
        end
    end
    case "get_result"
        retiring_records()
        # Get running result
        var body = get_post_body()
        var data = db.exec("SELECT STATE, DATA FROM INSTANCE WHERE ID=\"" + body.id + "\"")
        if !data.empty()
            var (state, dat) = data[0]
            if state.data == "DONE"
                system.out.print(dat.data)
            else
                system.out.print(state.data)
            end
        else
            system.out.print("NULL")
        end
    end
    case "get_data"
        # Get running production
        var body = get_post_body()
        var data = get_image_blob(db, "SELECT DATA FROM RESULT WHERE ID=\"" + body.id + "\"")
        if data != null
            system.out.print(data)
        else
            system.out.print("NULL")
        end
    end
end