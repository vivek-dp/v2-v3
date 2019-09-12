module RIOLOG
    module_function
    
    #Set log levels..............
    unless defined?(RIO_DEBUG)
        RIO_LOG_LEVEL = 31
        
        RIO_FATAL   = 16
        RIO_ERROR   =  8
        RIO_WARN    =  4
        RIO_INFO    =  2
        RIO_DEBUG   =  1
    end
    
    def rdebug(message)
        if RIO_LOG_LEVEL & RIO_DEBUG
            puts "RIODEBUG:  #{message}"
        end
    end

    def rinfo(message)
        if RIO_LOG_LEVEL & RIO_INFO
            puts "RIODEBUG:  #{message}"
        end
    end

    def rwarn(message)
        if RIO_LOG_LEVEL & RIO_WARN
            puts "RIODEBUG:  #{message}"
        end
    end

    def rerror(message)
        if RIO_LOG_LEVEL & RIO_ERROR
            puts "RIODEBUG:  #{message}"
        end
    end

    def rfatal(message)
        if RIO_LOG_LEVEL & RIO_FATAL
            puts "RIODEBUG:  #{message}"
        end
    end
    
end