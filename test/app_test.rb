require_relative 'helper'
include PagoEfectivo

scope do
  test 'should set dev api_server when initialize without option' do
    client = PagoEfectivo::Client.new
    api_server = client.instance_variable_get(:@api_server)
    assert api_server == 'https://pre.pagoefectivo.pe'
  end

  test 'should set prod api_server when initialize if you set option' do
    client = PagoEfectivo::Client.new('production')
    api_server = client.instance_variable_get(:@api_server)
    assert api_server == 'https://pagoefectivo.pe'
  end

  test 'create_markup generate valid xml' do
    client = PagoEfectivo::Client.new
    xml = Gyoku.xml({key: 'value'})
    markup = client.create_markup(xml)
    assert markup.include?('?xml')
    assert markup.include?('xmlns:soap')
  end
end
