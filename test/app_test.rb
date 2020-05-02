require_relative 'helper'
include PagoEfectivo

scope do
  setup do
    @client = PagoEfectivo::Client.new
  end

  test 'should set dev api_server when initialize without option' do
    api_server = @client.instance_variable_get(:@api_server)
    assert_equal api_server, 'https://pre.2b.pagoefectivo.pe'
  end

  test 'should set prod api_server when initialize if you set option' do
    client = PagoEfectivo::Client.new(env: 'production')
    api_server = client.instance_variable_get(:@api_server)
    assert_equal api_server, 'https://pagoefectivo.pe'
  end

  test 'create_markup generate valid xml' do
    xml = Gyoku.xml({key: 'value'})
    markup = @client.create_markup(xml)
    assert markup.include?('?xml')
  end

  test 'set_key should keep key like binary' do
  end

  test '#generate_xml' do
    params = {
      cod_serv: 'RSI',
      currency: PagoEfectivo::CURRENCIES[:soles],
      total: '22.00',
      pay_method: 1,
      cod_transaction: 'OR001024',
      email: 'mail@example.com',
      user: {
        first_name: 'Jhon',
        last_name: 'Doe',
        doc_type: 'DNI',
        doc_num: '37283937',
        id: 293,
        email: 'user@example.com'
      },
      additional_data: '',
      exp_date: '31/10/2014 17:00:00',
      place: {loc: 'San Isidro', prov: 'Lima', country: 'Peru'},
      pay_concept: 'some order reference',
      origin_code: ''
    }
    xml = @client.generate_xml(params)
    xml_doc = Nokogiri::XML(xml)
    wrapper = xml_doc.xpath('//SolPago')
    assert_equal wrapper.count, 1
    currency_xpath = wrapper.xpath('//IdMoneda')
    assert_equal currency_xpath.count, 1
    assert_equal currency_xpath.first.children.text, params[:currency][:id].to_s
  end
end
