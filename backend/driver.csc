import codec.base64.standard as base64
import csdbc_mysql as mysql
import codec.json as json
import process

# Settings, please fill before using
var backend_path = ""
var conn_str = "Driver={" + backend_path + "/libmaodbc.so};SERVER=localhost;USER=;PASSWORD=;DATABASE=;PORT=3306"

var enable_log = true
var stdlog = iostream.fstream(backend_path + "/driver.log", iostream.openmode.app)

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

# CREATE TABLE INSTANCE(ID VARCHAR(255), STATE VARCHAR(255), DATA TEXT, TIME VARCHAR(255))
# CREATE TABLE RESULT(ID VARCHAR(255), DATA LONGTEXT)
var db = mysql.connect_str(conn_str)

var id = context.cmd_args[1]
db.just_exec("UPDATE INSTANCE SET STATE=\"WORKING\" WHERE ID=\"" + id + "\"")
var data_str = base64.decode(db.exec("SELECT DATA FROM INSTANCE WHERE ID=\"" + id + "\"")[0][0].data)
log("Start working, ID = " + id + ", ARGS = " + data_str)
var data_obj = json.to_var(json.from_string(data_str))
var p = process.exec("docker", {"exec", id, "/workspace/upload/run.sh", data_obj.data})
log("Collecting results, ID = " + id)
var pout = p.out()
var results = new array
foreach it in range(5) do results.push_back(pout.getline())
p.wait()
process.exec("docker", {"stop", "-t", "0", id}).wait()
var (str1, str2, str3, str4, str5) = results
full = json.to_var(json.from_string(full))
full.push_front(full[0] + full[1] + full[2])
@begin
var json_data = {
    "field1": str1,
    "field2": {str2, str3, str4}
}.to_hash_map()
@end
json_data = base64.encode(json.to_string(json.from_var(json_data)))
log("Writing database, ID = " + id)
var stmt = null
stmt = db.prepare("UPDATE INSTANCE SET STATE=\"DONE\", DATA=? WHERE ID=?")
stmt.bind(0, json_data)
stmt.bind(1, id)
stmt.just_exec()
stmt = db.prepare("INSERT INTO RESULT VALUES(?,?)")
stmt.bind(0, id)
stmt.bind(1, str5)
stmt.just_exec()
log("Job done, ID = " + id)