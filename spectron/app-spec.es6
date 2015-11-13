import {Application} from 'spectron';

describe('Nylas', ()=> {
  beforeEach((done)=>{
    this.app = new Application({
      path: jasmine.APP_PATH,
    });
    this.app.start().then(done);
  });

  afterEach((done)=> {
    if (this.app && this.app.isRunning()) {
      this.app.stop().then(done);
    }
  });

  it('shows an initial window', ()=> {
    this.app.client.getWindowCount().then((count)=> {
      expect(count).toEqual(1);
    });
  });
});

