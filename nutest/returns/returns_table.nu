use ../store.nu
use ../formatter.nu

use std-rfc/iter [recurse]

def error-span-offset [offset: int]: [
	record<msg, labels, code, url, help, inner> -> record<msg, labels, code, url, help, inner>
] {
	let IN
	$IN
	| recurse --depth-first inner
	| update item.labels.span {
		{
			start: ($in.start - $offset)
			end: ($in.end - $offset)
		}
	}
	| reduce -f $IN {|e| upsert $e.path $e.item}
}

export def create []: nothing -> record {
	let formatter = {|row|
		each {|msg| $msg.items }
        | flatten
		| each {|e|
            match $e {
                {$msg, $rendered, $json} => {
                    {
                        msg: $msg
                        rendered: $rendered
                        data: ($json | from json | error-span-offset $row.span_offset)
                    }
                }
                $_ => $_
            }
		}
	}

    {
        name: "returns table"
        results: { query-results $formatter }
    }
}

def query-results [
    formatter: closure
]: nothing -> table<suite: string, test: string, result: string, output: string> {

    store query | each { |row|
        {
            suite: $row.suite
            test: $row.test
            result: $row.result
            output: ($row.output | do $formatter $row)
        }
    }
}
