require 'sinatra'
require 'json'
require 'net/https'

class APIUtils

    WEBSITE = 'https://www.jiandaoyun.com'
    RETRY_IF_LIMITED = true

    # 构造函数
    def initialize(appId, entryId, api_key)
        @url_get_widgets = WEBSITE + "/api/v1/app/#{ appId }/entry/#{ entryId }/widgets"
        @url_get_data = WEBSITE + "/api/v1/app/#{ appId }/entry/#{ entryId }/data"
        @url_retrieve_data = WEBSITE + "/api/v1/app/#{ appId }/entry/#{ entryId }/data_retrieve"
        @url_update_data = WEBSITE + "/api/v1/app/#{ appId }/entry/#{ entryId }/data_update"
        @url_create_data = WEBSITE + "/api/v1/app/#{ appId }/entry/#{ entryId }/data_create"
        @url_delete_data = WEBSITE + "/api/v1/app/#{ appId }/entry/#{ entryId }/data_delete"
        @api_key = api_key
    end

    # 获取请求头
    def get_request_header
        {
            # 认证信息
            'Authorization' => "Bearer #{ @api_key }",
            'Content-Type' => 'application/json;charset=utf-8'
        }
    end

    # 发送http请求
    def send_request(method, url, data)
        uri = URI.parse(url)
        header = get_request_header
        if method === 'GET'
            param_str = '?'
            i = 0
            data.each do |k, v|
                if i != 0
                    param_str += '&'
                end
                param_str += "#{ k }=#{ v.is_a?(Hash) ? v.to_json : v }"
                i += 1
            end
            req = Net::HTTP::Get.new(uri + param_str, header)
        else
            req = Net::HTTP::Post.new(uri.path, header)
            req.body = data.to_json
        end
        http_cli = Net::HTTP.new(uri.host, uri.port)
        http_cli.use_ssl = true
        http_cli.verify_mode = OpenSSL::SSL::VERIFY_NONE
        res = http_cli.start{ |http| http.request(req) }
        result = JSON.parse(res.body)
        if res.is_a?(Net::HTTPBadRequest) || res.is_a?(Net::HTTPForbidden)
            if RETRY_IF_LIMITED && result['code'] == 8303
                sleep 5
                send_request(method, url, data)
            else
                # 抛出错误
                raise "Error Code: #{ result['code'] }, Error Msg: #{ result['msg'] }"
            end
        else
            result
        end
    end

    # 获取表单字段
    def get_form_widgets
        result = send_request('POST', @url_get_widgets, {})
        result['widgets']
    end

    # 获取表单数据
    def get_form_data (dataId, limit, fields, filter)
        request_data = {
            :data_id => dataId,
            :limit => limit,
            :fields => fields,
            :filter => filter
        }
        result = send_request('POST', @url_get_data, request_data)
        result['data']
    end

    # 获取全部数据
    def get_all_data (fields, filter)
        form_data = []
        def get_next_page (form_data, dataId, fields, filter)
            data = get_form_data(dataId, 100, fields, filter)
            unless data.nil? || data.empty?
                form_data << data
                get_next_page(form_data, data.last['_id'], fields, filter)
            end
        end
        get_next_page(form_data, nil, fields, filter)
        form_data
    end

    # 检索单条数据
    def retrieve_data (dataId)
        result = send_request('POST', @url_retrieve_data, {
            :data_id => dataId
        })
        result['data']
    end

    # 创建单条数据
    def create_data (data)
        result = send_request('POST', @url_create_data, {
            :data => data
        })
        result['data']
    end

    # 更新单条数据
    def update_data (dataId, data)
        result = send_request('POST', @url_update_data, {
            :data_id => dataId,
            :data => data
        })
        result['data']
    end

    # 删除单条数据
    def delete_data (dataId)
        send_request('POST', @url_delete_data, {
            :data_id => dataId
        })
    end

end


def demo
    appId = '5b1747e93b708d0a80667400'
    entryId = '5b1749ae3b708d0a80667408'
    api_key = 'CTRP5jibfk7qnnsGLCCcmgnBG6axdHiX'

    api = APIUtils.new(appId, entryId, api_key)

    # 获取表单字段
    widgets = api.get_form_widgets
    puts('表单字段查询结果：')
    puts(widgets)

    # 根据条件获取表单前100条数据
    data = api.get_form_data(nil, 100, %w(_widget_1528252846720 _widget_1528252846801), {
        :rel => 'and',
        :cond => [
            {
                :field => '_widget_1528252846720',
                :type => 'text',
                :method => 'empty'
            }
        ]
    })
    puts('前100条数据查询结果：')
    puts(data)

    # 获取全部表单数据
    form_data = api.get_all_data([], {})
    puts('全部表单数据查询结果：')
    puts(form_data)

    # 创建单条数据
    create_data = api.create_data(
        {
            # 单行文本
            :_widget_1528252846720 => {
                :value => '123'
            },
            # 子表单
            :_widget_1528252846801 => {
                :value => [
                    {
                        :_widget_1528252846952 => {
                            :value => '123'
                        }
                    }
                ]
            },
            # 数字
            :_widget_1528252847027 => {
                :value => 123
            },
            # 地址
            :_widget_1528252846785 => {
                :value => {
                    :province => '江苏省',
                    :city => '无锡市',
                    :district => '南长区',
                    :detail => '清名桥街道'
                }
            },
            # 多行文本
            :_widget_1528252846748 => {
                :value => '123123'
            }
        }
    )
    puts('创建后的数据：')
    puts(create_data)

    # 更新单条数据
    update_result = api.update_data(create_data['_id'], {
        # 单行文本
        :_widget_1528252846720 => {
            :value => '123'
        },
        # 子表单
        :_widget_1528252846801 => {
            :value => [
                {
                    :_widget_1528252846952 => {
                        :value => '123'
                    }
                }
            ]
        },
        # 数字
        :_widget_1528252847027 => {
            :value => 123
        },
        # 地址
        :_widget_1528252846785 => {
            :value => {
                :province => '江苏省',
                :city => '无锡市',
                :district => '南长区',
                :detail => '清名桥街道'
            }
        },
        # 多行文本
        :_widget_1528252846748 => {
            :value => '123123'
        }
    })
    puts('更新结果：')
    puts(update_result)

    # 查询单条数据
    retrieve_data = api.retrieve_data(create_data['_id'])
    puts('单条数据查询结果：')
    puts(retrieve_data)

    # 删除单条数据
    delete_result = api.delete_data(create_data['_id'])
    puts('删除结果：')
    puts(delete_result)

end

demo