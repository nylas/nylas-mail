import {Application} from 'spectron';

describe('Nylas', ()=> {
  beforeAll((done)=>{
    this.app = new Application({
      path: jasmine.APP_PATH,
      args: jasmine.APP_ARGS,
    });
    this.app.start().then(()=> setTimeout(done, jasmine.BOOT_WAIT));
  });

  afterEach((done)=> {
    if (this.app && this.app.isRunning()) {
      this.app.stop().then(done);
    }
  });

  it('boots 4 windows on launch', (done)=> {
    this.app.client.getWindowCount().then((count)=> {
      expect(count).toEqual(4);
      done();
    });
  });
});

