import codec.base64.standard as base64
import csdbc_mysql as mysql
import codec.json as json
import process

# Settings, please fill before using
var backend_path = ""
var conn_str = "Driver={" + backend_path + "/libmaodbc.so};SERVER=localhost;USER=;PASSWORD=;DATABASE=;PORT=3306"

var enable_log = true
var stdlog = iostream.fstream(backend_path + "/queue.log", iostream.openmode.app)

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

if context.cmd_args.size == 1
    system.out.print("ERROR")
    system.exit(0)
end

var table_name = context.cmd_args[1], concurrent_limit = context.cmd_args[2].to_number(), command = base64.decode(context.cmd_args[3])
# CREATE TABLE INSTANCE(ID VARCHAR(255), STATE VARCHAR(255), DATA TEXT, TIME VARCHAR(255))
# CREATE TABLE RESULT(ID VARCHAR(255), DATA LONGTEXT)
var db = mysql.connect_str(conn_str)
var stmt = db.prepare("SELECT DISTINCT COUNT(ID) FROM " + table_name + " WHERE STATE=\'WORKING\'")
loop
    var current = stmt.exec()[0][0].data.to_number()
    if current < concurrent_limit
        log("Queue finished: " + command)
        break
    else
        log("Queueing: " + command + ", remaining " + current)
        runtime.delay(500)
    end
end
process.exec("cs", command.split({' '}))
